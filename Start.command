#!/bin/zsh

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"

chmod +x \
  "${SCRIPT_DIR}/Start.command" \
  "${SCRIPT_DIR}/install.sh" \
  "${SCRIPT_DIR}/test.sh" \
  "${SCRIPT_DIR}/doctor.sh" \
  "${SCRIPT_DIR}/uninstall.sh"

clear
printf 'ipad-as-a-display\n\n'
printf 'This is the one-click setup.\n'
printf 'Keep a normal monitor connected for this first run, connect the iPad over USB-C, and unlock it.\n\n'

status=0
"${SCRIPT_DIR}/install.sh" || status=$?

printf '\n'
if (( status == 0 )); then
  printf 'Done. If the iPad is already showing the Mac desktop, you can close this window.\n'
else
  printf 'Setup stopped with a message above. This window stayed open on purpose so you can read it.\n'
fi

printf '\nPress Return to close this window.'
read -r _

exit "${status}"
