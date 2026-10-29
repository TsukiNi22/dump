#!/bin/bash
# Take a webcam picture when the screen of WHOAMI is locked and no main usb is plugged
# (a cancel usb plugged also stops the picture)
# (MAIN_USBSV / CANCEL_USBSV (lists "<vendor-id>:<device-id>" separated by commas) / WHOAMI / USER_HOME / MAX_PICTURESV are replaced at the installation)
set -euo pipefail

MAIN_USBS="MAIN_USBSV"
CANCEL_USBS="CANCEL_USBSV"
OUTPUT_DIR="USER_HOME/Images/Intruder_Picture"
MAX_PICTURES="MAX_PICTURESV" # 0 = unlimited, else the oldest pictures are deleted

# Check that at least one usb of a list is plugged
any_plugged() {
    local usb

    for usb in ${1//,/ }; do
        if lsusb -d "$usb" > /dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

PHOTO_NAME="$OUTPUT_DIR/intruder_$(date +"%Y-%m-%d_%H-%M-%S").jpg"

session=$(loginctl list-sessions --no-legend | awk '$3 == "WHOAMI" && $6 == "user" {print $1; exit}')
if [[ -z "$session" ]]; then
    exit 0
fi
screen_locked=$(loginctl show-session "$session" -p LockedHint --value)

if [[ "$screen_locked" == "yes" ]] && ! any_plugged "$MAIN_USBS" && ! any_plugged "$CANCEL_USBS"; then
    mkdir -p "$OUTPUT_DIR"
    # fswebcam (fedora / debian), ffmpeg on arch (fswebcam only in the AUR)
    if command -v fswebcam > /dev/null; then
        fswebcam -q -r 1280x720 --jpeg 85 -D 1 "$PHOTO_NAME"
    else
        ffmpeg -loglevel error -f v4l2 -video_size 1280x720 -i /dev/video0 -frames:v 1 -y "$PHOTO_NAME"
    fi
    # The names hold the date -> sorted by name = from the oldest
    if [[ "$MAX_PICTURES" -gt 0 ]]; then
        find "$OUTPUT_DIR" -maxdepth 1 -name 'intruder_*.jpg' | sort | head -n -"$MAX_PICTURES" | xargs -r rm -f
    fi
fi
exit 0
