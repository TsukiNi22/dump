#!/bin/bash
# Usage: sudo bash pam_usb/launch.sh [<main usbs> [<cancel usbs>]] (lists: "<vendor-id>:<device-id>,...")
# Build pam_usb and require a main usb key in the auth stack (password AND one of the keys), deactivate it without usb
# (the cancel keys never unlock anything)
# Fedora-like / arch-like: marked block at the start of the auth stack, debian-like: pam-auth-update profile
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

MAIN_USBS="${1:-}"
CANCEL_USBS="${2:-}"
PAM_USB_REPO="https://github.com/mcdope/pam_usb.git"
PAM_BLOCK_START="# >>> dump_script pam_usb >>>"
PAM_BLOCK_END="# <<< dump_script pam_usb <<<"
PAM_LINE="auth        required                                     pam_usb.so"
DEB_PROFILE="/usr/share/pam-configs/dump-pam-usb" # Own debian profile (the one of pam_usb makes the usb sufficient alone)
DEB_PAM_USB_PROFILE="/usr/share/pam-configs/libpam-usb"

install_packages gum gcc make git python3 pkgconf-pkg-config pam-devel libxml2-devel glib2-devel \
    udisks-devel libudisks2-devel libevdev-devel || exit 1

# =========================
# Pam stack
# =========================
# Folder of the pam modules of this system (where pam_unix.so is)
pam_module_dir() {
    local module

    module=$(find /usr/lib64 /usr/lib /lib64 /lib -path '*/security/pam_unix.so' 2> /dev/null | head -n 1)
    dirname "$module"
}

# Auth files holding the block: fedora (authselect) system-auth & password-auth, arch system-auth
pam_files() {
    case "$OS_FAMILY" in
        rpm) echo "/etc/pam.d/system-auth /etc/pam.d/password-auth" ;;
        arch) echo "/etc/pam.d/system-auth" ;;
    esac
}

# Fedora: the authselect files rebuilt from the current profile (removes any old manual edit)
authselect_reset() {
    local profile

    if [[ "$OS_FAMILY" != "rpm" ]] || ! command -v authselect > /dev/null; then
        return 0
    fi
    profile=$(authselect current --raw 2> /dev/null) || return 0
    # shellcheck disable=SC2086 # <profile> <feature...>
    authselect select $profile --force > /dev/null
    ok "Pam files rebuilt by authselect ($profile)"
}

# Remove pam_usb from the auth stack
pam_disable() {
    local file

    if [[ "$OS_FAMILY" == "deb" ]]; then
        if [[ -f "$DEB_PROFILE" ]]; then
            pam-auth-update --package --remove dump-pam-usb
            rm -f "$DEB_PROFILE"
        fi
        ok "Pam usb removed from the debian auth stack"
        return 0
    fi
    authselect_reset
    for file in $(pam_files); do
        if [[ -f "$file" ]]; then
            sed -i "/^$PAM_BLOCK_START\$/,/^$PAM_BLOCK_END\$/d" "$file"
            ok "Pam usb removed from $file"
        fi
    done
}

# Require pam_usb in the auth stack (required: password AND usb key, a later sufficient module can't skip it)
pam_enable() {
    local file

    if [[ "$OS_FAMILY" == "deb" ]]; then
        # The profile of pam_usb (usb alone, enabled by default) must not be applied by a next pam-auth-update
        rm -f "$DEB_PAM_USB_PROFILE"
        # The profile lines of a field start with a tab (pam-auth-update format)
        printf '%s\n' \
            "Name: pam_usb required (dump_script: password AND usb key)" \
            "Default: yes" \
            "Priority: 0" \
            "Auth-Type: Additional" \
            "Auth:" \
            "$(printf '\trequired\tpam_usb.so')" > "$DEB_PROFILE"
        pam-auth-update --package --enable dump-pam-usb
        ok "Pam usb added to the debian auth stack (pam-auth-update)"
        return 0
    fi
    pam_disable
    for file in $(pam_files); do
        # Block before the first auth line
        awk -v start="$PAM_BLOCK_START" -v line="$PAM_LINE" -v end="$PAM_BLOCK_END" '
            !done && /^-?auth[[:space:]]/ { print start; print line; print end; done = 1 }
            { print }
        ' "$file" > "$file.dump_script" && cat "$file.dump_script" > "$file" && rm -f "$file.dump_script"
        ok "Pam usb required in $file"
    done
}

# =========================
# Program
# =========================
CHOICE="Deactivate"
if usbs_any_plugged "$MAIN_USBS"; then
    CHOICE=$(ask_choose "Pam usb:" "Activate" "Deactivate") || CHOICE="Cancel"
fi
case "$CHOICE" in
    "Activate") ;;
    "Deactivate") pam_disable; exit 0 ;;
    *) skipped "Pam usb"; exit 0 ;;
esac

# Build, installed in the pam folder of this system (the Makefile guesses it wrong on arch)
PAM_DIR=$(pam_module_dir)
if [[ -z "$PAM_DIR" || "$PAM_DIR" == "." ]]; then
    failed "Can't find the pam modules folder (pam_unix.so)"
    exit 1
fi
build_dir=$(mktemp -d)
trap 'rm -rf "$build_dir"' EXIT
box_open "DOWNLOAD-PAM-USB"
build_status=0
git clone --depth 1 "$PAM_USB_REPO" "$build_dir" \
    && make -C "$build_dir" > /dev/null \
    && make -C "$build_dir" install LIBDIR="${PAM_DIR#/}" PAM_USB_DEST="$PAM_DIR" > /dev/null \
    || build_status=1
box_close "DOWNLOAD-PAM-USB"

# A missing module (or library) in the auth stack would block every login !!!
if [[ "$build_status" -ne 0 || ! -f "$PAM_DIR/pam_usb.so" ]]; then
    failed "Build of pam usb ($PAM_DIR/pam_usb.so not installed)"
    exit 1
fi
if ldd "$PAM_DIR/pam_usb.so" | grep -q "not found"; then
    failed "pam_usb.so misses libraries: $(ldd "$PAM_DIR/pam_usb.so" | grep 'not found' | awk '{print $1}' | tr '\n' ' ')"
    exit 1
fi
ok "Download pam usb ($PAM_DIR/pam_usb.so)"

if ! bash "$SCRIPT_DIR/set-file.sh" "$MAIN_USBS" "$CANCEL_USBS"; then
    failed "Setup of the pam usb config"
    exit 1
fi
pam_enable
ok "Pam usb: password AND a main usb key required to log in"
