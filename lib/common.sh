#!/bin/zsh

APP_NAME="ipad-as-a-display"
LAUNCHD_LABEL="local.ipad-as-a-display"
APP_SUPPORT_DIR="${HOME}/Library/Application Support/${APP_NAME}"
BIN_DIR="${APP_SUPPORT_DIR}/bin"
CONFIG_FILE="${APP_SUPPORT_DIR}/config.env"
SERVICE_SCRIPT_PATH="${APP_SUPPORT_DIR}/${APP_NAME}.sh"
MONITOR_SOURCE_PATH="${APP_SUPPORT_DIR}/${APP_NAME}-monitor.swift"
MONITOR_BINARY_PATH="${APP_SUPPORT_DIR}/${APP_NAME}-monitor"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
LOG_STDOUT="/tmp/${APP_NAME}.log"
LOG_STDERR="/tmp/${APP_NAME}.err"
BETTERDISPLAY_PATH="/Applications/BetterDisplay.app/Contents/MacOS/BetterDisplay"
SIDECARLAUNCHER_PATH="${BIN_DIR}/SidecarLauncher"
SIDECARLAUNCHER_RELEASE_API="https://api.github.com/repos/Ocasio-J/SidecarLauncher/releases/latest"
SIDECARLAUNCHER_FALLBACK_URL="https://github.com/Ocasio-J/SidecarLauncher/releases/download/1.2/SidecarLauncher.zip"

say() {
  printf '%s\n' "$*"
}

print_status() {
  printf '%-26s %-5s %s\n' "$1" "$2" "$3"
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

launch_agent_print() {
  launchctl print "gui/$(id -u)/${LAUNCHD_LABEL}" 2>/dev/null
}

launch_agent_loaded() {
  launch_agent_print >/dev/null
}

load_config() {
  [[ -r "${CONFIG_FILE}" ]] || return 1
  source "${CONFIG_FILE}"
}

betterdisplay_is_installed() {
  [[ -x "${BETTERDISPLAY_PATH}" ]]
}

betterdisplay_is_running() {
  pgrep -x BetterDisplay >/dev/null 2>&1
}

sidecar_device_is_reachable() {
  local device_name="${1:-${DEVICE_NAME:-}}"

  [[ -n "${device_name}" ]] || return 1
  [[ -x "${SIDECARLAUNCHER_PATH}" ]] || return 1
  "${SIDECARLAUNCHER_PATH}" devices 2>/dev/null | grep -Fxq "${device_name}"
}

sidecar_is_connected() {
  local device_name="${1:-${DEVICE_NAME:-}}"

  if betterdisplay_is_installed && [[ -n "${device_name}" ]]; then
    "${BETTERDISPLAY_PATH}" get -identifiers 2>/dev/null | grep -Fq "\"name\" : \"${device_name}\""
    return $?
  fi

  system_profiler SPDisplaysDataType 2>/dev/null | grep -Fq "Sidecar Display:"
}

ipad_is_main_display() {
  local device_name="${1:-${DEVICE_NAME:-}}"

  betterdisplay_is_installed || return 1
  [[ -n "${device_name}" ]] || return 1
  "${BETTERDISPLAY_PATH}" get -name="${device_name}" -main 2>/dev/null | grep -Fxq "true"
}
