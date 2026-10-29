#!/bin/bash
# Usage: sudo bash wayland/launch.sh
# (asks which config: every style with the switcher, one style alone, or remove)
# Hyprland and the configs of the wayland-desktop repository (styles inspired by its POCs): its install.sh installs the
# packages of the chosen config for the distribution (fedora-like, debian-like, arch-like), then the configs for the user
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

WAYLAND_REPO_URL="https://github.com/$GITHUB_USER/wayland-desktop.git"
WAYLAND_LOCAL_DIR="$USER_HOME/personal_delivery/other/wayland-desktop" # Clone of the Git setup (when on its main branch)
WAYLAND_MANAGED_DIR="$USER_HOME/.local/share/wayland-desktop"
CONFIG_DIR=""

# =========================
# Setups
# =========================
# The configs: local clone on main (Git setup), else a managed clone kept up to date
setup_source() {
    if [[ -f "$WAYLAND_LOCAL_DIR/install.sh" ]]; then
        CONFIG_DIR="$WAYLAND_LOCAL_DIR"
        info "Configs of the local clone ($WAYLAND_LOCAL_DIR)"
        return 0
    fi
    CONFIG_DIR="$WAYLAND_MANAGED_DIR"
    if [[ -d "$WAYLAND_MANAGED_DIR/.git" ]]; then
        run_as_user git -C "$WAYLAND_MANAGED_DIR" pull -q --ff-only
    else
        run_as_user mkdir -p "$(dirname "$WAYLAND_MANAGED_DIR")" \
            && run_as_user git clone -q --depth 1 -b main "$WAYLAND_REPO_URL" "$WAYLAND_MANAGED_DIR"
    fi
}

# install.sh as root (sudo): the packages of the mode, then the configs for $SUDO_USER
setup_wayland() {
    bash "$CONFIG_DIR/install.sh" "$1"
}

# =========================
# Program
# =========================
install_packages gum git || exit 1

CHOICE=$(ask_choose "Wayland config:" \
    "Wayland (every style + switcher)" "System" "Dev / low level" "Ado / blue rose" "Terminal / better-tty" \
    "Miku" "Photographer" "Remove the config") || CHOICE="Cancel"
case "$CHOICE" in
    "Wayland (every style + switcher)") MODE="all" ;;
    "System") MODE="system" ;;
    "Dev / low level") MODE="dev" ;;
    "Ado / blue rose") MODE="ado" ;;
    "Terminal / better-tty") MODE="tty" ;;
    "Miku") MODE="miku" ;;
    "Photographer") MODE="photographer" ;;
    "Remove the config") MODE="remove" ;;
    *)
        skipped "Wayland setup"
        exit 0
        ;;
esac

run_step "SETUP-WAYLAND-SOURCE" "wayland-desktop configs" setup_source || exit 1
run_step "SETUP-WAYLAND" "Wayland: $CHOICE (packages + configs)" setup_wayland "$MODE" || exit 1
if [[ "$MODE" != "remove" ]]; then
    info "Log out and choose Hyprland at the login screen (Super: overview, Super+Shift+W: style menu)"
fi
