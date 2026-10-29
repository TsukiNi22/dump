#!/bin/bash
# Usage: sudo bash take_screen_of_intruder/set-file.sh <main usbs> [<max pictures> (0 = unlimited) [<cancel usbs>]]
# (lists: "<vendor-id>:<device-id>,...")
# Install the capture scripts and start the usb-capture service for the user
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

MAIN_USBS="${1:?Error: missing main usbs}"
MAX_PICTURES="${2:-0}"
CANCEL_USBS="${3:-}"
SERVICE="usb-capture.service"
BIN_DIR="/usr/local/bin"

if overlap=$(usbs_overlap "$MAIN_USBS" "$CANCEL_USBS"); then
    failed "A key can't be both a main key and a cancel key ($overlap)"
    exit 1
fi

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

sed -e "s|MAIN_USBSV|$(escape_sed "$MAIN_USBS")|g" \
    -e "s|CANCEL_USBSV|$(escape_sed "$CANCEL_USBS")|g" \
    -e "s|WHOAMI|$(escape_sed "$SUDO_USER")|g" \
    -e "s|USER_HOME|$(escape_sed "$USER_HOME")|g" \
    -e "s|MAX_PICTURESV|$(escape_sed "$MAX_PICTURES")|g" \
    "$SCRIPT_DIR/check-usb-and-capture.sh" > "$tmp_file"
install_root_file 755 "$tmp_file" "$BIN_DIR/check-usb-and-capture.sh"
ok "Usb-And-Capture script setup"

install_root_file 755 "$SCRIPT_DIR/usb-capture-listener.sh" "$BIN_DIR/usb-capture-listener.sh"
ok "Usb-Capture-Listener script setup"

sed "s|WHOAMI|$(escape_sed "$SUDO_USER")|g" "$SCRIPT_DIR/$SERVICE" > "$tmp_file"
install_root_file 644 "$tmp_file" "/etc/systemd/system/$SERVICE"
ok "Usb-Capture service setup"

systemctl daemon-reload
systemctl enable "$SERVICE"
systemctl restart "$SERVICE"
ok "Start of the Usb-Capture service"
