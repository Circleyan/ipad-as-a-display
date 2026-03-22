#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
source "${SCRIPT_DIR}/lib/common.sh"

if [[ "${1:-}" != "--yes" ]]; then
  printf 'Remove ipad-as-a-display from this Mac? [y/N]: '
  read -r reply
  reply="${reply:-n}"
  case "${reply:l}" in
    y|yes) ;;
    *) exit 0 ;;
  esac
fi

launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" 2>/dev/null || launchctl bootout "gui/$(id -u)/${LAUNCHD_LABEL}" 2>/dev/null || true
rm -f "${PLIST_PATH}"
rm -rf "${APP_SUPPORT_DIR}"
rm -f "${LOG_STDOUT}" "${LOG_STDERR}"

say "Uninstalled ${APP_NAME}."
say "BetterDisplay was not removed."
