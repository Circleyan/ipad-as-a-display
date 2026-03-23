#!/bin/zsh

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

TEST_REASON="manual-test"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from-install)
      TEST_REASON="post-install-test"
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./test.sh [--from-install]

Options:
  --from-install  Use friendlier copy when install.sh calls the test automatically.
EOF
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
  shift
done

load_config || fail "No installed configuration found. Run Start.command first."
[[ -x "${SERVICE_SCRIPT_PATH}" ]] || fail "Installed recovery script is missing: ${SERVICE_SCRIPT_PATH}"

say "Running one automatic recovery cycle..."

service_status=0
"${SERVICE_SCRIPT_PATH}" --reason "${TEST_REASON}" || service_status=$?

say ""
say "Current status:"
"${SCRIPT_DIR}/doctor.sh"
say ""

if (( service_status == 0 )); then
  say "Automatic test completed."
else
  say "Automatic test did not fully connect yet."
  say "Read the diagnosis above first. Most fixes are just unlocking the iPad, trusting the Mac, or reconnecting USB-C."
fi

say ""
say "Manual checks to do now:"
say "  1. Confirm the iPad shows the macOS desktop."
say "  2. Unplug the USB-C cable once and confirm the iPad returns to normal iPad mode."
say "  3. Plug USB-C back in, unlock the iPad, and confirm the Mac desktop returns."
say "  4. If the Mac sleeps, wake it once with your keyboard or trackpad while the iPad stays connected."

exit "${service_status}"
