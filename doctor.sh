#!/bin/zsh

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

say "ipad-as-a-display doctor"
say "----------------------"

if betterdisplay_is_installed; then
  print_status "BetterDisplay installed" "OK" "${BETTERDISPLAY_PATH}"
else
  print_status "BetterDisplay installed" "MISS" "Install BetterDisplay before using this setup."
fi

if betterdisplay_is_running; then
  print_status "BetterDisplay running" "OK" "App process is active."
else
  print_status "BetterDisplay running" "WARN" "Open BetterDisplay before trying to reconnect."
fi

if [[ -x "${SIDECARLAUNCHER_PATH}" ]]; then
  print_status "SidecarLauncher" "OK" "${SIDECARLAUNCHER_PATH}"
else
  print_status "SidecarLauncher" "MISS" "Run Start.command first."
fi

if ! load_config; then
  print_status "Config file" "MISS" "First-time setup has not finished yet."
  say ""
  say "Diagnosis"
  say "  Start.command has not completed yet."
  say ""
  say "Next action"
  say "  Double-click Start.command and let it finish once while a normal monitor is still attached."
  exit 0
fi

print_status "Config file" "OK" "${CONFIG_FILE}"
print_status "Configured iPad" "OK" "${DEVICE_NAME}"
print_status "Recovery mode" "OK" "${RECOVERY_MODE:-wake-and-usb-events}"
print_status "Set iPad as main" "OK" "${SET_IPAD_AS_MAIN_DISPLAY}"

if [[ -x "${MONITOR_BINARY_PATH}" ]]; then
  print_status "Event monitor" "OK" "${MONITOR_BINARY_PATH}"
else
  print_status "Event monitor" "MISS" "Run Start.command again to rebuild the local helper."
fi

if [[ -f "${PLIST_PATH}" ]]; then
  print_status "LaunchAgent file" "OK" "${PLIST_PATH}"
else
  print_status "LaunchAgent file" "MISS" "LaunchAgent is not installed."
fi

if launch_agent_loaded; then
  print_status "LaunchAgent loaded" "OK" "${LAUNCHD_LABEL}"
else
  print_status "LaunchAgent loaded" "WARN" "The local helper is not loaded in launchd."
fi

if sidecar_device_is_reachable "${DEVICE_NAME}"; then
  print_status "iPad reachable" "OK" "${DEVICE_NAME} is visible to SidecarLauncher."
else
  print_status "iPad reachable" "WARN" "${DEVICE_NAME} is not currently reachable."
fi

if sidecar_is_connected "${DEVICE_NAME}"; then
  print_status "Sidecar connected" "OK" "${DEVICE_NAME} is online."
else
  print_status "Sidecar connected" "WARN" "Sidecar is not connected right now."
fi

if ipad_is_main_display "${DEVICE_NAME}"; then
  print_status "iPad is main display" "OK" "${DEVICE_NAME}"
else
  print_status "iPad is main display" "WARN" "${DEVICE_NAME} is not the main display right now."
fi

if [[ -f "${LOG_STDOUT}" ]]; then
  print_status "Recent log" "OK" "${LOG_STDOUT}"
fi

say ""
say "Diagnosis"

if ! betterdisplay_is_installed; then
  say "  BetterDisplay is missing, so the setup cannot keep the Mac mini usable without the normal monitor."
  say ""
  say "Next action"
  say "  Install BetterDisplay, open it once, then double-click Start.command again."
elif [[ ! -x "${SIDECARLAUNCHER_PATH}" || ! -x "${MONITOR_BINARY_PATH}" ]]; then
  say "  Core helper files are missing, so the setup is incomplete."
  say ""
  say "Next action"
  say "  Double-click Start.command again to reinstall the helper."
elif ! launch_agent_loaded; then
  say "  The helper is installed but not currently loaded, so wake and USB events will not auto-recover the iPad."
  say ""
  say "Next action"
  say "  Run Start.command again. If that still fails, log out and back in once, then rerun ./doctor.sh."
elif ! sidecar_device_is_reachable "${DEVICE_NAME}"; then
  say "  The helper looks installed, but the iPad is not reachable right now."
  say ""
  say "Next action"
  say "  Keep USB-C connected, unlock the iPad, trust the Mac if prompted, and make sure both devices still use the same Apple Account."
elif ! sidecar_is_connected "${DEVICE_NAME}"; then
  say "  The iPad is reachable, but Sidecar is not connected yet."
  say ""
  say "Next action"
  say "  Leave BetterDisplay open, reconnect USB-C once, unlock the iPad, then rerun ./test.sh."
else
  say "  The setup looks healthy. This Mac should be able to recover the iPad screen on wake and USB replug."
  say ""
  say "Next action"
  say "  Unplug USB-C once, then plug it back in and unlock the iPad to confirm the real-world workflow."
fi

if [[ -f "${LOG_STDOUT}" ]]; then
  say ""
  say "Last 5 log lines"
  tail -n 5 "${LOG_STDOUT}" 2>/dev/null
fi
