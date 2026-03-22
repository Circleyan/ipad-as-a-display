#!/bin/zsh

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

print_status() {
  local label="$1"
  local status="$2"
  local detail="$3"
  printf '%-26s %-5s %s\n' "${label}" "${status}" "${detail}"
}

sidecar_is_connected() {
  if [[ -x "${BETTERDISPLAY_PATH}" ]]; then
    "${BETTERDISPLAY_PATH}" get -identifiers 2>/dev/null | grep -Fq "\"name\" : \"${DEVICE_NAME}\""
    return $?
  fi

  system_profiler SPDisplaysDataType 2>/dev/null | grep -Fq "Sidecar Display:"
}

if [[ -x "${BETTERDISPLAY_PATH}" ]]; then
  print_status "BetterDisplay installed" "OK" "${BETTERDISPLAY_PATH}"
else
  print_status "BetterDisplay installed" "MISS" "Install BetterDisplay before using this setup."
fi

if pgrep -x BetterDisplay >/dev/null 2>&1; then
  print_status "BetterDisplay running" "OK" "App process is active."
else
  print_status "BetterDisplay running" "WARN" "The app is not running right now."
fi

if [[ -x "${SIDECARLAUNCHER_PATH}" ]]; then
  print_status "SidecarLauncher" "OK" "${SIDECARLAUNCHER_PATH}"
else
  print_status "SidecarLauncher" "MISS" "Run ./install.sh first."
fi

if load_config; then
  print_status "Config file" "OK" "${CONFIG_FILE}"
  print_status "Configured iPad" "OK" "${DEVICE_NAME}"
  print_status "Recovery mode" "OK" "${RECOVERY_MODE:-wake-and-usb-events}"
  print_status "Set iPad as main" "OK" "${SET_IPAD_AS_MAIN_DISPLAY}"
else
  print_status "Config file" "MISS" "Run ./install.sh first."
  exit 0
fi

if [[ -x "${MONITOR_BINARY_PATH}" ]]; then
  print_status "Event monitor" "OK" "${MONITOR_BINARY_PATH}"
else
  print_status "Event monitor" "MISS" "Run ./install.sh first."
fi

if [[ -f "${PLIST_PATH}" ]]; then
  print_status "LaunchAgent file" "OK" "${PLIST_PATH}"
else
  print_status "LaunchAgent file" "MISS" "LaunchAgent is not installed."
fi

if launch_agent_loaded; then
  print_status "LaunchAgent loaded" "OK" "${LAUNCHD_LABEL}"
else
  print_status "LaunchAgent loaded" "WARN" "Not loaded in launchd."
fi

if "${SIDECARLAUNCHER_PATH}" devices 2>/dev/null | grep -Fxq "${DEVICE_NAME}"; then
  print_status "iPad reachable" "OK" "${DEVICE_NAME} is visible to SidecarLauncher."
else
  print_status "iPad reachable" "WARN" "${DEVICE_NAME} is not currently reachable."
fi

if sidecar_is_connected; then
  print_status "Sidecar connected" "OK" "${DEVICE_NAME} is online."
else
  print_status "Sidecar connected" "WARN" "Sidecar is not connected right now."
fi

if [[ -x "${BETTERDISPLAY_PATH}" ]] && "${BETTERDISPLAY_PATH}" get -name="${DEVICE_NAME}" -main 2>/dev/null | grep -Fxq "true"; then
  print_status "iPad is main display" "OK" "${DEVICE_NAME}"
else
  print_status "iPad is main display" "WARN" "${DEVICE_NAME} is not the main display right now."
fi

if [[ -f "${LOG_STDOUT}" ]]; then
  print_status "Recent log" "OK" "${LOG_STDOUT}"
  tail -n 5 "${LOG_STDOUT}" 2>/dev/null
fi
