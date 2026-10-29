#!/bin/bash
# Usage: sudo bash wayland/launch.sh
# (asks which config: every style with the switcher, one style alone, or remove)
# Hyprland, waybar and the configs of the wayland-desktop repository (styles inspired by its POCs), installed for the user
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

WAYLAND_REPO_URL="https://github.com/$GITHUB_USER/wayland-desktop.git"
WAYLAND_LOCAL_DIR="$USER_HOME/personal_delivery/other/wayland-desktop" # Clone of the Git setup (when on its main branch)
WAYLAND_MANAGED_DIR="$USER_HOME/.local/share/wayland-desktop"
HYPRLAND_COPR="sdegler/hyprland" # Fedora: hyprland, hyprlock (not in the Fedora repositories)
PACKAGES=(hyprland hyprlock waybar wofi kitty swaybg mako grim slurp wl-clipboard brightnessctl playerctl wireplumber
    libnotify nautilus adwaita-cursor-theme jetbrains-mono-fonts-all fontawesome-6-free-fonts google-noto-sans-cjk-fonts)
CONFIG_DIR=""

# =========================
# Setups
# =========================
# Fedora: the hyprland copr (the debian-like and arch-like repositories have hyprland)
setup_repository() {
    if [[ "$OS_FAMILY" != "rpm" ]] || pkg_available hyprland; then
        return 0
    fi
    pkg_install dnf-plugins-core && dnf copr enable -y "$HYPRLAND_COPR"
}

setup_packages() {
    setup_repository || warning "Copr $HYPRLAND_COPR can't be enabled (hyprland may be missing)"
    pkg_install "${PACKAGES[@]}"
}

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

setup_configs() {
    run_as_user env XDG_CONFIG_HOME="$USER_HOME/.config" bash "$CONFIG_DIR/install.sh" "$1"
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

status=0
if [[ "$MODE" != "remove" ]]; then
    run_step "SETUP-WAYLAND-PACKAGES" "Hyprland, waybar & tools" setup_packages || status=1
fi
run_step "SETUP-WAYLAND-SOURCE" "wayland-desktop configs" setup_source || exit 1
run_step "SETUP-WAYLAND-CONFIG" "Config: $CHOICE" setup_configs "$MODE" || status=1
if [[ "$MODE" != "remove" && "$status" -eq 0 ]]; then
    info "Log out and choose Hyprland at the login screen (Super+Shift+W: style menu)"
fi
exit "$status"
