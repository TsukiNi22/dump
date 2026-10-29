#!/bin/bash
# Usage: usb-lock_power-shutdown.sh lock|shutdown (run by the udev rules)
# Lock & suspend (a main usb removed) or power off (charger unplugged), unless a cancel usb is plugged,
# the lock also needs that no other main usb is still plugged
# (MAIN_USBSV / CANCEL_USBSV / WHOAMI are replaced at the installation, lists of "<vendor-id>:<device-id>" separated by commas)
set -euo pipefail

MAIN_USBS="MAIN_USBSV"
CANCEL_USBS="CANCEL_USBSV"

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

if any_plugged "$CANCEL_USBS"; then
    exit 0
fi

case "${1:-}" in
    lock)
        # Another main usb is still there: the session stays open
        if any_plugged "$MAIN_USBS"; then
            exit 0
        fi
        session=$(loginctl list-sessions --no-legend | awk '$3 == "WHOAMI" && $6 == "user" {print $1; exit}')
        if [[ -n "$session" ]]; then
            loginctl lock-session "$session"
        fi
        systemctl suspend
        ;;
    shutdown)
        systemctl poweroff
        ;;
esac
