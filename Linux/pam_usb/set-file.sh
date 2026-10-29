#!/bin/bash
# Usage: sudo bash pam_usb/set-file.sh <main usbs> [<cancel usbs>] (lists: "<vendor-id>:<device-id>,...")
# Write /etc/security/pam_usb.conf with every plugged main usb (any of them unlocks the session),
# the cancel keys are refused: they can't be used to log in (the auth stack is edited by launch.sh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

MAIN_USBS="${1:?Error: missing main usbs}"
CANCEL_USBS="${2:-}"

if overlap=$(usbs_overlap "$MAIN_USBS" "$CANCEL_USBS"); then
    failed "A key can't be both a main key and a cancel key ($overlap)"
    exit 1
fi

# =========================
# Usb information
# =========================
# Print the <device> block of a usb (<vendor-id>:<device-id>) as "Usb<n>", return 1 when it can't be used
device_block() {
    local usb="$1"
    local index="$2"
    local vendor_id="${usb%%:*}"
    local device_id="${usb##*:}"
    local usb_path=""
    local dir model vendor serial disk uuid

    # Sysfs folder of the usb (the one whose idVendor / idProduct match)
    for dir in /sys/bus/usb/devices/*; do
        if [[ "$(cat "$dir/idVendor" 2> /dev/null)" == "$vendor_id" \
            && "$(cat "$dir/idProduct" 2> /dev/null)" == "$device_id" ]]; then
            usb_path="$dir"
            break
        fi
    done
    if [[ -z "$usb_path" ]]; then
        warning "Can't access the usb $usb (not plugged): skipped" >&2
        return 1
    fi
    model=$(cat "$usb_path/product" 2> /dev/null || echo "Unknown")
    vendor=$(cat "$usb_path/manufacturer" 2> /dev/null || echo "Unknown")
    serial=$(cat "$usb_path/serial" 2> /dev/null || echo "")
    if [[ -z "$serial" ]]; then
        warning "The usb $usb has no serial number (needed by pam usb): skipped" >&2
        return 1
    fi
    # Uuid of the first volume of the disk with this serial
    disk=$(lsblk -dnrpo NAME,SERIAL | awk -v serial="$serial" '$2 == serial {print $1; exit}')
    uuid=""
    if [[ -n "$disk" ]]; then
        uuid=$(lsblk -nro UUID "$disk" | grep -m 1 . || true)
    fi
    if [[ -z "$uuid" ]]; then
        warning "Can't find the volume uuid of the usb $usb (serial: $serial): skipped" >&2
        return 1
    fi
    printf '    <device id="Usb%s">\n      <vendor>%s</vendor>\n      <model>%s</model>\n      <serial>%s</serial>\n      <volume_uuid>%s</volume_uuid>\n    </device>\n' \
        "$index" "$vendor" "$model" "$serial" "$uuid"
}

devices=""
user_devices=""
count=0
for usb in ${MAIN_USBS//,/ }; do
    if block=$(device_block "$usb" "$((count + 1))"); then
        count=$((count + 1))
        devices+="$block"$'\n'
        user_devices+="      <device>Usb$count</device>"$'\n'
    fi
done
# No usable key would lock everybody out of the login
if [[ "$count" -eq 0 ]]; then
    failed "No main usb can be used by pam usb"
    exit 1
fi
ok "$count main usb key(s) set for pam usb"

# =========================
# Files
# =========================
tmp_conf=$(mktemp)
tmp_devices=$(mktemp)
tmp_user=$(mktemp)
trap 'rm -f "$tmp_conf" "$tmp_devices" "$tmp_user"' EXIT
printf '%s' "${devices%$'\n'}" > "$tmp_devices"
printf '%s' "${user_devices%$'\n'}" > "$tmp_user"
awk -v devices="$tmp_devices" -v users="$tmp_user" '
    /^DEVICES_BLOCK$/ { while ((getline line < devices) > 0) print line; next }
    /^USER_DEVICES_BLOCK$/ { while ((getline line < users) > 0) print line; next }
    { print }
' "$SCRIPT_DIR/pam_usb.conf" \
    | sed -e "s|WHOAMI|$(escape_sed "$SUDO_USER")|g" > "$tmp_conf"
ok "Set of the pam_usb.conf devices"

install_root_file 644 "$tmp_conf" /etc/security/pam_usb.conf
ok "Pam usb config file setup"
