#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

load_config || fail "No installed configuration found. Run ./install.sh first."
[[ -x "${SERVICE_SCRIPT_PATH}" ]] || fail "Installed recovery script is missing: ${SERVICE_SCRIPT_PATH}"

say "Running one recovery cycle..."
"${SERVICE_SCRIPT_PATH}"
say ""
say "Current status:"
"${SCRIPT_DIR}/doctor.sh"
say ""
say "Manual checks to do now:"
say "  1. Confirm the iPad shows the macOS desktop."
say "  2. Unplug the USB-C cable once and confirm the iPad returns to normal iPad mode."
say "  3. Plug USB-C back in, unlock the iPad, and confirm the Mac desktop returns."
say "  4. If you allow the Mac to sleep, wake it once with your keyboard or trackpad while the iPad stays connected."
