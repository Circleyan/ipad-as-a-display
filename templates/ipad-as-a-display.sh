#!/bin/zsh

set -u

APP_SUPPORT_DIR="${HOME}/Library/Application Support/ipad-as-a-display"
CONFIG_FILE="${APP_SUPPORT_DIR}/config.env"
STATE_FILE="${APP_SUPPORT_DIR}/last_state"

if [[ ! -r "${CONFIG_FILE}" ]]; then
  exit 1
fi

source "${CONFIG_FILE}"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

set_state() {
  local next_state="$1"
  local message="$2"
  local previous_state=""

  if [[ -r "${STATE_FILE}" ]]; then
    previous_state="$(<"${STATE_FILE}")"
  fi

  if [[ "${previous_state}" != "${next_state}" ]]; then
    printf '%s' "${next_state}" > "${STATE_FILE}"
    log "${message}"
  fi
}

sidecar_is_connected() {
  if [[ -x "${BETTERDISPLAY_PATH}" ]]; then
    "${BETTERDISPLAY_PATH}" get -identifiers 2>/dev/null | grep -Fq "\"name\" : \"${DEVICE_NAME}\""
    return $?
  fi

  system_profiler SPDisplaysDataType 2>/dev/null | grep -Fq "Sidecar Display:"
}

ensure_sidecar_is_main() {
  if [[ "${SET_IPAD_AS_MAIN_DISPLAY:-true}" != "true" ]]; then
    return 0
  fi

  if [[ ! -x "${BETTERDISPLAY_PATH}" ]]; then
    return 0
  fi

  if "${BETTERDISPLAY_PATH}" get -name="${DEVICE_NAME}" -main 2>/dev/null | grep -Fxq "true"; then
    return 0
  fi

  if "${BETTERDISPLAY_PATH}" set -name="${DEVICE_NAME}" -main=on >/dev/null 2>&1; then
    log "${DEVICE_NAME} set as main display"
  else
    log "Failed to set ${DEVICE_NAME} as main display"
  fi
}

if [[ ! -x "${SIDECARLAUNCHER_PATH}" ]]; then
  set_state "missing-launcher" "SidecarLauncher not found at ${SIDECARLAUNCHER_PATH}"
  exit 1
fi

if sidecar_is_connected; then
  ensure_sidecar_is_main
  set_state "connected" "${DEVICE_NAME} is connected"
  exit 0
fi

if ! "${SIDECARLAUNCHER_PATH}" devices 2>/dev/null | grep -Fxq "${DEVICE_NAME}"; then
  set_state "unreachable" "${DEVICE_NAME} is not reachable"
  exit 0
fi

log "Found ${DEVICE_NAME}, trying wired Sidecar"
if "${SIDECARLAUNCHER_PATH}" connect "${DEVICE_NAME}" -wired >/dev/null 2>&1; then
  ensure_sidecar_is_main
  set_state "connected" "Wired Sidecar connected"
  exit 0
fi

log "Wired connect failed, retrying with default transport"
if "${SIDECARLAUNCHER_PATH}" connect "${DEVICE_NAME}" >/dev/null 2>&1; then
  ensure_sidecar_is_main
  set_state "connected" "Default Sidecar connected"
  exit 0
fi

set_state "reconnect-failed" "Sidecar reconnect failed"
exit 1
