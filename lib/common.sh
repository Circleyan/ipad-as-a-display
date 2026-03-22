#!/bin/zsh

APP_NAME="ipad-as-a-display"
LAUNCHD_LABEL="local.ipad-as-a-display"
APP_SUPPORT_DIR="${HOME}/Library/Application Support/${APP_NAME}"
BIN_DIR="${APP_SUPPORT_DIR}/bin"
CONFIG_FILE="${APP_SUPPORT_DIR}/config.env"
SERVICE_SCRIPT_PATH="${APP_SUPPORT_DIR}/${APP_NAME}.sh"
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
