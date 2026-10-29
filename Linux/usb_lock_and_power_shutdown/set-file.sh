#!/bin/bash
# Usage: sudo bash usb_lock_and_power_shutdown/set-file.sh <main usbs> [<cancel usbs>] (lists: "<vendor-id>:<device-id>,...")
# Install the detection script run by the udev rules
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

MAIN_USBS="${1:-}"
CANCEL_USBS="${2:-}"
DETECTION_SCRIPT="/usr/local/bin/usb-lock_power-shutdown.sh"

if overlap=$(usbs_overlap "$MAIN_USBS" "$CANCEL_USBS"); then
    failed "A key can't be both a main key and a cancel key ($overlap)"
    exit 1
fi
if [[ -z "$CANCEL_USBS" ]]; then
    warning "No cancel usb: the lock & shutdown can't be cancelled"
fi

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT
sed -e "s|MAIN_USBSV|$(escape_sed "$MAIN_USBS")|g" \
    -e "s|CANCEL_USBSV|$(escape_sed "$CANCEL_USBS")|g" \
    -e "s|WHOAMI|$(escape_sed "$SUDO_USER")|g" \
    "$SCRIPT_DIR/usb-lock_power-shutdown.sh" > "$tmp_file"
install_root_file 755 "$tmp_file" "$DETECTION_SCRIPT"
ok "Detection script setup"
