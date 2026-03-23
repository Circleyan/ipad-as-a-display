#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

RUN_SMOKE_TEST="true"

usage() {
  cat <<'EOF'
Usage: ./install.sh [--install-only]

Options:
  --install-only  Install the helper, but skip the automatic post-install test.
EOF
}

detect_swiftc_path() {
  local swiftc_path=""

  if command -v swiftc >/dev/null 2>&1; then
    swiftc_path="$(command -v swiftc)"
  elif command -v xcrun >/dev/null 2>&1; then
    swiftc_path="$(xcrun --find swiftc 2>/dev/null || true)"
  fi

  [[ -n "${swiftc_path}" ]] && printf '%s\n' "${swiftc_path}"
}

run_preflight() {
  local failures=0
  local swiftc_path=""

  say "Quick preflight"
  say "---------------"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    print_status "macOS" "OK" "This Mac can run the setup."
  else
    print_status "macOS" "MISS" "This installer only supports macOS."
    failures=$(( failures + 1 ))
  fi

  if betterdisplay_is_installed; then
    print_status "BetterDisplay" "OK" "${BETTERDISPLAY_PATH}"
  else
    print_status "BetterDisplay" "MISS" "Install BetterDisplay first, then run Start.command again."
    failures=$(( failures + 1 ))
  fi

  if betterdisplay_is_running; then
    print_status "BetterDisplay app" "OK" "BetterDisplay is already running."
  else
    print_status "BetterDisplay app" "WARN" "Open BetterDisplay before you start using the iPad."
  fi

  for command_name in curl python3 unzip install; do
    if command -v "${command_name}" >/dev/null 2>&1; then
      print_status "${command_name}" "OK" "Command is available."
    else
      print_status "${command_name}" "MISS" "Required command is missing."
      failures=$(( failures + 1 ))
    fi
  done

  swiftc_path="$(detect_swiftc_path || true)"
  if [[ -n "${swiftc_path}" ]]; then
    print_status "swiftc" "OK" "${swiftc_path}"
  else
    print_status "swiftc" "MISS" "Run xcode-select --install first, then run Start.command again."
    failures=$(( failures + 1 ))
  fi

  say ""
  if (( failures > 0 )); then
    fail "Fix the items marked MISS above, then run Start.command again."
  fi
}

download_sidecarlauncher() {
  local download_url tmp_dir zip_path

  download_url="$(
    python3 <<'PY'
import json
import urllib.request

api_url = "https://api.github.com/repos/Ocasio-J/SidecarLauncher/releases/latest"
fallback_url = "https://github.com/Ocasio-J/SidecarLauncher/releases/download/1.2/SidecarLauncher.zip"

try:
    with urllib.request.urlopen(api_url, timeout=15) as response:
        data = json.load(response)
    for asset in data.get("assets", []):
        if asset.get("name") == "SidecarLauncher.zip":
            print(asset["browser_download_url"])
            raise SystemExit(0)
except Exception:
    pass

print(fallback_url)
PY
  )"

  tmp_dir="$(mktemp -d)"
  zip_path="${tmp_dir}/SidecarLauncher.zip"

  curl -fsSL "${download_url}" -o "${zip_path}"
  unzip -joq "${zip_path}" -d "${BIN_DIR}"
  chmod +x "${SIDECARLAUNCHER_PATH}"
  xattr -d com.apple.quarantine "${SIDECARLAUNCHER_PATH}" 2>/dev/null || true
  rm -rf "${tmp_dir}"
}

find_swiftc() {
  local swiftc_path=""

  swiftc_path="$(detect_swiftc_path || true)"
  [[ -n "${swiftc_path}" ]] || fail "swiftc is required to build the local event monitor. Install Xcode Command Line Tools first, then rerun install."
  SWIFTC_PATH="${swiftc_path}"
}

compile_monitor() {
  install -m 644 "${SCRIPT_DIR}/templates/ipad-as-a-display-monitor.swift" "${MONITOR_SOURCE_PATH}"
  "${SWIFTC_PATH}" -framework AppKit -framework IOKit "${MONITOR_SOURCE_PATH}" -o "${MONITOR_BINARY_PATH}"
  chmod +x "${MONITOR_BINARY_PATH}"
}

prompt_yes_no() {
  local prompt="$1"
  local default_answer="$2"
  local reply

  while true; do
    if [[ "${default_answer}" == "y" ]]; then
      printf '%s [Y/n]: ' "${prompt}"
    else
      printf '%s [y/N]: ' "${prompt}"
    fi

    read -r reply
    reply="${reply:-${default_answer}}"

    case "${reply:l}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
    esac
  done
}

choose_device_name() {
  local devices device_count selected reply index
  local -a device_lines

  devices="$("${SIDECARLAUNCHER_PATH}" devices 2>/dev/null || true)"
  [[ -n "${devices}" ]] || fail "No reachable Sidecar iPad found. Unlock the iPad, trust this Mac, keep USB-C connected, then rerun Start.command."

  device_lines=("${(@f)devices}")
  device_count="${#device_lines[@]}"

  say ""
  say "Reachable iPad devices:"
  for (( index = 1; index <= device_count; index++ )); do
    printf '  %s. %s\n' "${index}" "${device_lines[${index}]}"
  done

  if [[ "${device_count}" -eq 1 ]]; then
    printf 'Use "%s"? [Y/n]: ' "${device_lines[1]}"
    read -r reply
    reply="${reply:-y}"
    case "${reply:l}" in
      y|yes)
        CHOSEN_DEVICE_NAME="${device_lines[1]}"
        return 0
        ;;
    esac
  fi

  while true; do
    printf 'Enter the iPad number to use: '
    read -r selected
    if [[ "${selected}" == <-> ]] && (( selected >= 1 && selected <= device_count )); then
      CHOSEN_DEVICE_NAME="${device_lines[${selected}]}"
      return 0
    fi
  done
}

write_config() {
  local device_name="$1"
  local set_main="$2"

  {
    printf 'DEVICE_NAME=%q\n' "${device_name}"
    printf 'SET_IPAD_AS_MAIN_DISPLAY=%q\n' "${set_main}"
    printf 'RECOVERY_MODE=%q\n' "wake-and-usb-events"
    printf 'BETTERDISPLAY_PATH=%q\n' "${BETTERDISPLAY_PATH}"
    printf 'SIDECARLAUNCHER_PATH=%q\n' "${SIDECARLAUNCHER_PATH}"
  } > "${CONFIG_FILE}"
}

write_plist() {
  cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LAUNCHD_LABEL}</string>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>ProgramArguments</key>
  <array>
    <string>${MONITOR_BINARY_PATH}</string>
  </array>
  <key>KeepAlive</key>
  <true/>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_STDOUT}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_STDERR}</string>
</dict>
</plist>
EOF
}

install_launch_agent() {
  launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" 2>/dev/null || launchctl bootout "gui/$(id -u)/${LAUNCHD_LABEL}" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}"
  launchctl kickstart -k "gui/$(id -u)/${LAUNCHD_LABEL}" >/dev/null 2>&1 || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-only|--skip-test)
      RUN_SMOKE_TEST="false"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
  shift
done

require_command curl
require_command python3
require_command unzip
require_command install

mkdir -p "${BIN_DIR}" "$(dirname -- "${PLIST_PATH}")"

say "ipad-as-a-display"
say ""
say "This setup is meant to feel like one button:"
say "  1. Keep a normal monitor connected for this first install."
say "  2. Connect the iPad over USB-C and unlock it."
say "  3. Trust this Mac on the iPad if prompted."
say "  4. Keep BetterDisplay installed."
say ""

run_preflight

say "Step 1/4: downloading SidecarLauncher"
download_sidecarlauncher

say "Step 2/4: checking the local Swift compiler"
find_swiftc

say "Step 3/4: choosing the iPad to use"
choose_device_name
DEVICE_NAME="${CHOSEN_DEVICE_NAME}"

if prompt_yes_no "Always make the iPad the main display?" "y"; then
  SET_IPAD_AS_MAIN_DISPLAY="true"
else
  SET_IPAD_AS_MAIN_DISPLAY="false"
fi

say "Step 4/4: installing the local helper"
write_config "${DEVICE_NAME}" "${SET_IPAD_AS_MAIN_DISPLAY}"
install -m 755 "${SCRIPT_DIR}/templates/ipad-as-a-display.sh" "${SERVICE_SCRIPT_PATH}"
compile_monitor
write_plist
plutil -lint "${PLIST_PATH}" >/dev/null
install_launch_agent

say ""
say "Install complete."
say "  iPad name: ${DEVICE_NAME}"
say "  Recovery mode: wake + USB replug events"
say "  Make iPad main display: ${SET_IPAD_AS_MAIN_DISPLAY}"

if [[ "${RUN_SMOKE_TEST}" == "true" ]]; then
  say ""
  say "Now I will run one automatic test for you."
  "${SCRIPT_DIR}/test.sh" --from-install
else
  say ""
  say "Next step: run ./test.sh once while the normal monitor is still attached."
fi
