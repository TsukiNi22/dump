#!/bin/bash
# Usage: bash describe.sh <menu entry>
# Details of a menu entry, shown in the preview of the menu (fzf)
set -euo pipefail

BOLD=$'\033[1m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
GREY=$'\033[90m'
RESET=$'\033[0m'

title() {
    echo "${BOLD}${MAGENTA}$1${RESET}"
    echo "${GREY}$(printf '─%.0s' $(seq 1 ${#1}))${RESET}"
    echo
}

note() {
    echo
    echo "${YELLOW}⚠ $1${RESET}"
}

# Bullets "- " -> "•", lines ending with ':' -> cyan sub-titles
format() {
    sed -e "s/^\( *\)- /\1${CYAN}•${RESET} /" -e "s/^\([A-Z][^•]*:\)$/${CYAN}${BOLD}\1${RESET}/"
}

{
    case "${1:-}" in
        "System Update")
            title "System Update"
            echo "Runs on the loading screen at launch, run it again from here:"
            echo "  - system update (dnf / apt / pacman)"
            echo "  - packages of the menu: gum, fzf, usbutils, less, curl"
            ;;
        "Pam Usb"*)
            title "Pam Usb"
            echo "${YELLOW}Needs a main usb key${RESET} (not set: chosen when the setup starts, or deactivation only)"
            echo
            echo "Activate (main usb plugged):"
            echo "  - build pam_usb from github.com/mcdope/pam_usb"
            echo "  - write /etc/security/pam_usb.conf (vendor, model, serial, volume uuid of every plugged main usb: any of them unlocks)"
            echo "  - password AND one main usb required (never a cancel usb) to log in / unlock / sudo:"
            echo "    fedora: marked block in system-auth & password-auth (rebuilt by authselect first)"
            echo "    debian: pam-auth-update profile, arch: marked block in system-auth"
            echo
            echo "Deactivate:"
            echo "  - remove the block / profile (password only)"
            note "Enabled only when pam_usb.so is in the pam folder with all its libraries (no lock-out)"
            ;;
        "Usb Lock & Power Shutdown"*)
            title "Usb Lock & Power Shutdown"
            echo "${YELLOW}Needs a main usb key${RESET} (not set: chosen when the setup starts, or deactivation only)"
            echo
            echo "Activation (main usb plugged), choose USB Lock, Power Shutdown or both:"
            echo "  - USB Lock: one udev rule per main usb, the last main usb removed -> lock the session + suspend"
            echo "  - Power Shutdown: udev rule, charger unplugged -> power off"
            echo "  - /usr/local/bin/usb-lock_power-shutdown.sh run by the rules"
            echo "  - cancel usbs (optional): one plugged -> the lock / shutdown don't happen"
            echo
            echo "Deactivation (always possible, one of them or both):"
            echo "  - remove the rule(s), the script when no rule is left, reload udev"
            ;;
        "Screen Of Intruder"*)
            title "Screen Of Intruder"
            echo "${YELLOW}Needs a main usb key${RESET} (not set: chosen when the setup starts, or deactivation only)"
            echo
            echo "Activate (main usb plugged):"
            echo "  - install fswebcam"
            echo "  - usb-capture.service (runs as the user) checks every second"
            echo "  - screen locked AND no main usb plugged (nor cancel usb) -> webcam picture in"
            echo "    ~/Images/Intruder_Picture/intruder_<date>.jpg"
            echo "  - max number of pictures kept (asked, 0 = unlimited): the oldest ones are deleted"
            echo
            echo "Deactivate:"
            echo "  - stop & remove the service and its scripts"
            ;;
        "Usb Keys"*)
            title "Usb Keys"
            echo "Optional: choose the usbs used by the 3 usb setups, as many as you want (from lsusb or written by hand):"
            echo "  - main keys (security): Pam Usb, Usb Lock & Power Shutdown, Screen Of Intruder"
            echo "  - cancel keys (optional): cancel the Usb Lock & Power Shutdown and the Screen Of Intruder"
            note "A key is either a main key or a cancel key, never both (refused)"
            note "Not set: the usb setups propose to choose it when they start (or deactivation only)"
            ;;
        "Dotfile")
            title "Dotfile"
            echo "Packages: neovim, vim, zsh, zoxide, fastfetch, chafa, sl, tmux, gcc, tree-sitter-cli"
            echo
            echo "  - Oh-My-Zsh (unattended), zsh as default shell"
            echo "  - ~/.zshrc (old one saved in ~/.zshrc.bak), 'dump' alias -> this repository"
            echo "  - ~/.config/nvim: lazy.nvim, rose-pine, treesitter, nvim-cmp, headers & protos"
            echo "  - ~/.config/fastfetch: random picture at each launch (rdm_img.sh)"
            echo "  - ~/.tmux.conf + ~/.config/tmux/mode.sh (vi modes), ~/.config/git/ignore"
            ;;
        "Package & App")
            title "Package & App"
            echo "Repositories: RPM Fusion (free & nonfree), Flathub, vscode"
            echo
            echo "  - base: git, curl, wget, tree, ripgrep, gh, asciiquarium"
            echo "  - dev: gcc, clang, cmake, ccache, gtest, valgrind, python3, tmux"
            echo "  - GPU drivers from the hardware (lspci): NVIDIA driver + CUDA, AMD mesa + ROCm, Intel media + vulkan"
            echo "  - libs (lua, json, httplib, sodium, libconfig, ncurses, qt6), htop, nmap, rsync, glow, doxygen, llvm, perf"
            echo "  - mingw64 cross compiler (fedora only)"
            echo "  - docker (moby-engine, docker-compose, docker group)"
            echo "  - CSFML, binwalk, gobuster, hydra, john, wireshark (wireshark group)"
            echo "  - apps: vscode, telegram, qbittorrent, vesktop & sober (flatpak)"
            note "A failed step is reported and the next ones still run"
            ;;
        "Custom Package & Binary")
            title "Custom Package & Binary"
            echo "Choose one or both:"
            echo "  - libutils: TsukiNi22 rpm / deb mirror (built from the sources on arch),"
            echo "    every build (optimized, debug, asan + headers)"
            echo "  - xstyle: coding style checker, built from the ai-utils repository into ~/.local/bin"
            note "xstyle needs libutils: select both on a fresh machine"
            ;;
        "AI")
            title "AI"
            echo "Choose any of:"
            echo "  - Claude Code: native installer (~/.local/bin/claude)"
            echo "  - Ollama: official installer (/usr/local/bin/ollama + ollama.service)"
            echo "  - Skills: every skill in ~/.claude/skills + their tools (xstyle)"
            echo "  - Skills context: CLAUDE.md, RTK.md, hooks and rtk in ~/.claude"
            note "The skills come from the local clone of the Git setup, or a managed clone otherwise"
            ;;
        "N8n")
            title "N8n"
            echo "n8n workflow automation, http://localhost:5678 (local only, data in the volume n8n_data):"
            echo "  - podman (rootless) + quadlet ~/.config/containers/systemd/n8n.container"
            echo "  - systemd user service n8n.service (host network, restarts always, started at login)"
            note "The image is pulled by the first start (can take a few minutes)"
            ;;
        "Git")
            title "Git"
            echo "  - git user (name, email), core.editor nvim, init.defaultBranch main"
            echo "  - ~/delivery & ~/personal_delivery repositories"
            echo "  - ~/.ssh/git key: ed25519 (or ed25519-sk on a FIDO2 key), passphrase typed hidden"
            echo "    on the terminal, 256 KDF rounds (slow brute force of a stolen key)"
            echo "  - github host in ~/.ssh/config: post-quantum key exchange only"
            echo "    (mlkem768x25519 / sntrup761x25519), key kept in the agent after the first unlock"
            echo "  - clone (https, push with ssh) any of:"
            echo "      libutils, cpp_project_template -> ~/personal_delivery/cpp/"
            echo "      ai-utils, docker-image -> ~/personal_delivery/other/"
            echo "      other links (one per line) -> chosen folder"
            ;;
        "Grub & Plymouth")
            title "Grub & Plymouth"
            echo "  - grub theme from a repository with an install.sh (optional, empty link to skip)"
            echo "  - plymouth theme of grub_plymouth/plymouth_theme (loader_2)"
            echo "  - regenerate the initramfs (can take a while)"
            ;;
        "Wayland")
            title "Wayland"
            echo "Hyprland + the configs of github.com/TsukiNi22/wayland-desktop (styles inspired by its POCs):"
            echo "  - packages: hyprland, hyprlock, waybar, wofi, kitty, swaybg, mako, grim, slurp, wl-clipboard,"
            echo "    brightnessctl, playerctl, nautilus, btop, adwaita cursor, fonts (fedora: copr sdegler/hyprland for hyprland & hyprlock),"
            echo "    quickshell (overview), cava (music bars), python GTK + WebKit 4.1 + gtk-layer-shell (live wallpapers)"
            echo "  - choose the config:"
            echo "      Wayland: every style + a switcher in the top bar (click: menu, scroll: next), Super: GNOME-like overview"
            echo "      or one style alone: System, Dev / low level, Ado / blue rose, Terminal / better-tty, Miku, Photographer"
            echo "      or remove the config (the saved files are put back)"
            echo "  - configs of the local clone (~/personal_delivery/other/wayland-desktop on main) or a managed clone"
            note "The files already there are saved once (*.wd-backup); log out and choose Hyprland at the login screen"
            ;;
        "Quit")
            title "Quit"
            echo "Leave the menu"
            ;;
        *)
            echo "No description for '${1:-}'"
            ;;
    esac
} | format
