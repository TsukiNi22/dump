#!/bin/bash
# Usage: sudo bash take_screen_of_intruder/launch.sh [<main usbs> [<cancel usbs>]] (lists: "<vendor-id>:<device-id>,...")
# (asks the max number of pictures kept: 0 = unlimited, else the oldest ones are deleted)
# Take a webcam picture when the screen is locked and no main usb is plugged (deactivate it without usb)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

MAIN_USBS="${1:-}"
CANCEL_USBS="${2:-}"
SERVICE="usb-capture.service"
BIN_DIR="/usr/local/bin"

install_packages gum fswebcam usbutils || exit 1

deactivate() {
    systemctl disable --now "$SERVICE" 2> /dev/null || true
    rm -f "/etc/systemd/system/$SERVICE" "$BIN_DIR/check-usb-and-capture.sh" "$BIN_DIR/usb-capture-listener.sh"
    systemctl daemon-reload
    ok "Usb-Capture service & scripts removed"
}

CHOICE="Deactivate"
if usbs_any_plugged "$MAIN_USBS"; then
    CHOICE=$(ask_choose "Screen of intruder:" "Activate" "Deactivate") || CHOICE="Cancel"
fi
case "$CHOICE" in
    "Activate") ;;
    "Deactivate") deactivate; exit 0 ;;
    *) skipped "Screen of intruder"; exit 0 ;;
esac

# Max number of pictures kept (0 = unlimited)
while true; do
    if ! MAX_PICTURES=$(ask_input "Max number of pictures kept (0 = unlimited):" "0"); then
        skipped "Screen of intruder"
        exit 0
    fi
    MAX_PICTURES="${MAX_PICTURES:-0}"
    if [[ "$MAX_PICTURES" =~ ^[0-9]+$ ]]; then
        break
    fi
    warning "'$MAX_PICTURES' is not a number"
done
if [[ "$MAX_PICTURES" -eq 0 ]]; then
    info "No limit of pictures"
else
    info "Only the $MAX_PICTURES last pictures are kept"
fi

if ! bash "$SCRIPT_DIR/set-file.sh" "$MAIN_USBS" "$MAX_PICTURES" "$CANCEL_USBS"; then
    failed "Setup of take screen of intruder file"
    exit 1
fi
