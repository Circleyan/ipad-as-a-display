#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

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

prompt_interval() {
  local reply interval

  printf 'Reconnect check interval in seconds [15]: '
  read -r reply
  interval="${reply:-15}"

  case "${interval}" in
    15|30)
      CHOSEN_INTERVAL="${interval}"
      ;;
    *)
      fail "Only 15 or 30 seconds are supported."
      ;;
  esac
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
  [[ -n "${devices}" ]] || fail "No reachable Sidecar iPad found. Unlock the iPad, trust this Mac, keep USB-C connected, then rerun install."

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
      y|yes) CHOSEN_DEVICE_NAME="${device_lines[1]}"; return 0 ;;
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
  local interval="$2"
  local set_main="$3"

  {
    printf 'DEVICE_NAME=%q\n' "${device_name}"
    printf 'CHECK_INTERVAL_SECONDS=%q\n' "${interval}"
    printf 'SET_IPAD_AS_MAIN_DISPLAY=%q\n' "${set_main}"
    printf 'BETTERDISPLAY_PATH=%q\n' "${BETTERDISPLAY_PATH}"
    printf 'SIDECARLAUNCHER_PATH=%q\n' "${SIDECARLAUNCHER_PATH}"
  } > "${CONFIG_FILE}"
}

write_plist() {
  local interval="$1"

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
    <string>/bin/zsh</string>
    <string>${SERVICE_SCRIPT_PATH}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>${interval}</integer>
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

require_command curl
require_command python3
require_command unzip

[[ "$(uname -s)" == "Darwin" ]] || fail "This installer only supports macOS."
[[ -x "${BETTERDISPLAY_PATH}" ]] || fail "BetterDisplay is required. Install BetterDisplay first, then rerun install."

mkdir -p "${BIN_DIR}" "$(dirname -- "${PLIST_PATH}")"

say "ipad-as-a-display"
say ""
say "First-time setup must be done while the Mac has a working screen and the iPad is connected over USB-C."
say "Before continuing:"
say "  1. Unlock the iPad."
say "  2. Trust this Mac on the iPad if prompted."
say "  3. Keep BetterDisplay installed."
say ""

download_sidecarlauncher

choose_device_name
prompt_interval
DEVICE_NAME="${CHOSEN_DEVICE_NAME}"
CHECK_INTERVAL_SECONDS="${CHOSEN_INTERVAL}"

if prompt_yes_no "Always make the iPad the main display?" "y"; then
  SET_IPAD_AS_MAIN_DISPLAY="true"
else
  SET_IPAD_AS_MAIN_DISPLAY="false"
fi

write_config "${DEVICE_NAME}" "${CHECK_INTERVAL_SECONDS}" "${SET_IPAD_AS_MAIN_DISPLAY}"
install -m 755 "${SCRIPT_DIR}/templates/ipad-as-a-display.sh" "${SERVICE_SCRIPT_PATH}"
write_plist "${CHECK_INTERVAL_SECONDS}"
plutil -lint "${PLIST_PATH}" >/dev/null
install_launch_agent

say ""
say "Install complete."
say "  iPad name: ${DEVICE_NAME}"
say "  Check interval: ${CHECK_INTERVAL_SECONDS}s"
say "  Make iPad main display: ${SET_IPAD_AS_MAIN_DISPLAY}"
say ""
say "Next step: run ./test.sh once while a normal monitor is still attached."
