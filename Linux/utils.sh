#!/bin/bash
# Shared helpers of the setup scripts (sourced only, never executed)
# Supported: fedora-like (dnf), debian-like (apt), arch-like (pacman)
set -euo pipefail

# =========================
# Colors
# =========================
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
GREY=$'\033[90m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# Same colors in the gum prompts (ANSI 5 = magenta, 6 = cyan)
export GUM_CHOOSE_CURSOR="👉 "
export GUM_CHOOSE_CURSOR_FOREGROUND="5"
export GUM_CHOOSE_HEADER_FOREGROUND="6"
export GUM_CHOOSE_SELECTED_FOREGROUND="5"
export GUM_INPUT_CURSOR_FOREGROUND="5"
export GUM_INPUT_PROMPT_FOREGROUND="6"
export GUM_INPUT_PROMPT="❯ "
export GUM_WRITE_CURSOR_FOREGROUND="5"
export GUM_WRITE_HEADER_FOREGROUND="6"

# =========================
# Display
# =========================
DISPLAY_WIDTH=60 # Width of the sections & boxes

# Print <count> times <char>
repeat() {
    local line=""
    local i

    for ((i = 0; i < $2; i++)); do
        line+="$1"
    done
    printf '%s' "$line"
}

# Center a text between <char> on <total> columns: center <char> <total> <text display width> <text>
center() {
    local left=$((($2 - $3) / 2))
    local right=$(($2 - $3 - left))

    echo "$(repeat "$1" "$left")$4$(repeat "$1" "$right")"
}

# =========================
# Logs
# =========================
# Tags of 8 columns -> the messages are aligned
ok() {
    echo "[  ${GREEN}OK${RESET}  ] $*"
}

failed() {
    echo "[${RED}${BOLD}FAILED${RESET}] $*" >&2
}

skipped() {
    echo "[ ${YELLOW}SKIP${RESET} ] $*"
}

warning() {
    echo "[ ${YELLOW}WARN${RESET} ] $*"
}

info() {
    echo "[ ${BLUE}INFO${RESET} ] $*"
}

# Section title of a setup: ════ [ NAME ] ════
# In the menu (DUMP_LOG set) sections & boxes are markers drawn by the preview at its own width
section() {
    if [[ -n "${DUMP_LOG:-}" ]]; then
        echo "@@SECTION@@ $1"
        return 0
    fi
    echo
    center "═" "$DISPLAY_WIDTH" $((${#1} + 6)) " [ ${BOLD}${CYAN}$1${RESET} ] "
}

# Box around the output of a command: ╔══ 🔻 [ NAME ] 🔻 ══╗ ... ╚══ 🔺 [ NAME ] 🔺 ══╝
# (an emoji takes 2 columns, the corners are outside of the centered part)
box_open() {
    if [[ -n "${DUMP_LOG:-}" ]]; then
        echo "@@BOX@@ $1"
        return 0
    fi
    echo "╔$(center "═" $((DISPLAY_WIDTH - 2)) $((${#1} + 12)) " 🔻 [ ${CYAN}$1${RESET} ] 🔻 ")╗"
}

box_close() {
    if [[ -n "${DUMP_LOG:-}" ]]; then
        echo "@@BOXEND@@ $1"
        return 0
    fi
    echo "╚$(center "═" $((DISPLAY_WIDTH - 2)) $((${#1} + 12)) " 🔺 [ ${CYAN}$1${RESET} ] 🔺 ")╝"
}

# =========================
# Questions
# =========================
# In the menu (dump.sh): the question is shown in the fzf window (--listen API) and the answer written back
# by the menu in $DUMP_STATE_DIR/ask. Run alone: gum prompts.
ASK_POLL_DELAY=0.2 # Seconds between two checks of the answer

in_menu() {
    [[ -n "${FZF_PORT:-}" && -n "${DUMP_STATE_DIR:-}" ]]
}

# Send actions to the fzf menu
fzf_post() {
    curl -s -XPOST "localhost:$FZF_PORT" -d "$1" > /dev/null
}

# Show a question in the menu and wait for its answer: menu_ask <kind> <header> <query> <actions> [option...]
# kind = choose | multi | input | write, prints the answer, return 1 when cancelled
menu_ask() {
    local kind="$1"
    local header="$2"
    local query="$3"
    local actions="$4"
    local dir="$DUMP_STATE_DIR/ask"
    shift 4

    command mkdir -p "$dir"
    rm -f "$dir/answer" "$dir/status"
    : > "$dir/options"
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$@" > "$dir/options"
    fi
    printf '%s' "$query" > "$dir/query"
    echo "$kind" > "$dir/kind"
    echo "${BOLD}${CYAN}$header${RESET}" > "$dir/header"
    case "$kind" in
        choose) echo "${GREY}enter validate • esc cancel${RESET}" >> "$dir/header" ;;
        multi) echo "${GREY}tab toggle • enter validate • esc cancel${RESET}" >> "$dir/header" ;;
        input) echo "${GREY}type • enter validate • esc cancel${RESET}" >> "$dir/header" ;;
        write) echo "${GREY}values separated by spaces • enter validate${RESET}" >> "$dir/header" ;;
    esac
    echo "answer" > "$DUMP_STATE_DIR/mode"
    fzf_post "reload-sync(cat $dir/options)+transform-header(cat $dir/header)+change-prompt(Answer ❯ )+show-input+enable-search+transform-query(cat $dir/query)+deselect-all+first+refresh-preview"
    # Separate request: the list must be reloaded before moving / selecting in it
    if [[ -n "$actions" ]]; then
        sleep "$ASK_POLL_DELAY"
        fzf_post "${actions#+}"
    fi

    while [[ ! -f "$dir/status" ]]; do
        sleep "$ASK_POLL_DELAY"
    done
    if [[ "$(cat "$dir/status")" != "ok" ]]; then
        return 1
    fi
    cat "$dir/answer"
}

# Run an interactive command on the terminal (hidden input: passphrase...): run_on_tty <header> <command...>
# In the menu fzf runs it (execute) and comes back to the window after it
run_on_tty() {
    local header="$1"
    local dir="$DUMP_STATE_DIR/tty"
    shift

    if ! in_menu; then
        "$@"
        return
    fi
    command mkdir -p "$dir"
    rm -f "$dir/status"
    {
        echo "clear"
        printf 'echo %q\n' "${BOLD}${CYAN}$header${RESET}"
        echo "echo"
        printf '%q ' "$@"
        echo
        echo "echo \$? > $(printf '%q' "$dir/status")"
    } > "$dir/run.sh"
    fzf_post "execute(bash $dir/run.sh)+refresh-preview"
    while [[ ! -f "$dir/status" ]]; do
        sleep "$ASK_POLL_DELAY"
    done
    return "$(cat "$dir/status")"
}

# Choose options: ask_choose [--multi] [--selected <a,b>] <header> <option...> (one answer per line)
# A "Cancel" option is always added (last): choosing it = esc, return 1
ask_choose() {
    local multi=false
    local selected=""
    local header
    local actions=""
    local answer
    local i

    while [[ "${1:-}" == --* ]]; do
        case "$1" in
            --multi) multi=true; shift ;;
            --selected) selected="$2"; shift 2 ;;
        esac
    done
    header="$1"
    shift
    if [[ "${!#}" != "Cancel" ]]; then
        set -- "$@" "Cancel"
    fi

    if ! in_menu && ! command -v gum > /dev/null; then
        # No gum (not in the debian repositories): fzf
        if [[ "$multi" == true ]]; then
            answer=$(printf '%s\n' "$@" | fzf --multi --header "$header (tab: toggle)" --height ~50%) || return 1
        else
            answer=$(printf '%s\n' "$@" | fzf --header "$header" --height ~50%) || return 1
        fi
    elif ! in_menu; then
        if [[ "$multi" == true ]]; then
            answer=$(gum choose --no-limit --selected="$selected" --header "$header" "$@") || return 1
        else
            answer=$(gum choose --header "$header" "$@") || return 1
        fi
    elif [[ "$multi" == false ]]; then
        answer=$(menu_ask choose "$header" "" "" "$@") || return 1
    else
        # Pre-selection: move on each selected option and select it
        for ((i = 1; i <= $#; i++)); do
            if [[ ",$selected," == *",${!i},"* ]]; then
                actions+="+pos($i)+select"
            fi
        done
        answer=$(menu_ask multi "$header" "" "$actions+first" "$@") || return 1
    fi
    if [[ -z "$answer" ]] || grep -qx "Cancel" <<< "$answer"; then
        return 1
    fi
    echo "$answer"
}

# Ask a text: ask_input <header> [default]
ask_input() {
    local answer

    if ! in_menu && ! command -v gum > /dev/null; then
        read -r -e -i "${2:-}" -p "$1 " answer < /dev/tty || return 1
        echo "$answer"
        return 0
    fi
    if ! in_menu; then
        gum input --placeholder "$1" --value "${2:-}"
        return
    fi
    menu_ask input "$1" "${2:-}" ""
}

# Ask several values (one per line in the answer): ask_write <header>
ask_write() {
    local answer

    if ! in_menu && ! command -v gum > /dev/null; then
        read -r -e -p "$1 (separated by spaces) " answer < /dev/tty || return 1
        tr -s ' ' '\n' <<< "$answer"
        return 0
    fi
    if ! in_menu; then
        gum write --height=10 --placeholder "$1 (one per line, ctrl+d to validate)"
        return
    fi
    menu_ask write "$1" "" ""
}

# =========================
# Tools
# =========================
# =========================
# Packages
# =========================
# Name of a package on this family, from its fedora name (empty = not in the repositories of the family)
pkg_name() {
    case "$OS_FAMILY:$1" in
        rpm:gpg) echo "gnupg2" ;;
        arch:gpg) echo "gnupg" ;;
        rpm:*) echo "$1" ;;
        # debian-like
        deb:vim-enhanced) echo "vim" ;;
        deb:gcc-c++) echo "g++" ;;
        deb:gtest-devel) echo "libgtest-dev" ;;
        deb:xeyes) echo "x11-apps" ;;
        deb:moby-engine) echo "docker.io" ;;
        deb:CSFML-devel) echo "libcsfml-dev" ;;
        deb:openssl-devel) echo "libssl-dev" ;;
        deb:pkgconf-pkg-config) echo "pkg-config" ;;
        deb:pam-devel) echo "libpam0g-dev" ;;
        deb:libxml2-devel) echo "libxml2-dev" ;;
        deb:glib2-devel) echo "libglib2.0-dev" ;;
        deb:libudisks2-devel) echo "libudisks2-dev" ;;
        deb:libevdev-devel) echo "libevdev-dev" ;;
        deb:openssh-clients) echo "openssh-client" ;;
        deb:grub2-tools) echo "grub-common" ;;
        deb:plymouth-system-theme) echo "plymouth-themes" ;;
        deb:util-linux-user|deb:dnf-plugins-core|deb:CSFML|deb:udisks-devel|deb:dracut|deb:grub2-common) ;;
        deb:plymouth-scripts|deb:plymouth-plugin-script) ;;
        # arch-like
        arch:vim-enhanced) echo "vim" ;;
        arch:gcc-c++) echo "gcc" ;;
        arch:gh) echo "github-cli" ;;
        arch:gtest-devel) echo "gtest" ;;
        arch:python3) echo "python" ;;
        arch:python3-pip) echo "python-pip" ;;
        arch:xeyes) echo "xorg-xeyes" ;;
        arch:moby-engine) echo "docker" ;;
        arch:CSFML) echo "csfml" ;;
        arch:wireshark) echo "wireshark-qt" ;;
        arch:fswebcam) echo "ffmpeg" ;; # fswebcam is only in the AUR: ffmpeg takes the pictures
        arch:openssl-devel) echo "openssl" ;;
        arch:pkgconf-pkg-config) echo "pkgconf" ;;
        arch:pam-devel) echo "pam" ;;
        arch:libxml2-devel) echo "libxml2" ;;
        arch:glib2-devel) echo "glib2" ;;
        arch:libudisks2-devel) echo "udisks2" ;;
        arch:libevdev-devel) echo "libevdev" ;;
        arch:openssh-clients) echo "openssh" ;;
        arch:grub2-tools) echo "grub" ;;
        arch:util-linux-user|arch:dnf-plugins-core|arch:CSFML-devel|arch:udisks-devel|arch:dracut) ;;
        arch:grub2-common|arch:plymouth-scripts|arch:plymouth-plugin-script|arch:plymouth-system-theme) ;;
        arch:asciiquarium) ;; # AUR only
        *) echo "$1" ;;
    esac
}

# Check that a package exists in the repositories of the family
pkg_available() {
    case "$OS_FAMILY" in
        rpm) dnf -q list --available "$1" > /dev/null 2>&1 || rpm -q "$1" > /dev/null 2>&1 ;;
        deb) [[ -n "$(apt-cache policy "$1" 2> /dev/null | grep 'Candidate:' | grep -v '(none)')" ]] ;;
        arch) pacman -Si "$1" > /dev/null 2>&1 || pacman -Q "$1" > /dev/null 2>&1 ;;
    esac
}

# Update every installed package
pkg_update() {
    case "$OS_FAMILY" in
        rpm) dnf update -y ;;
        deb) apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade ;;
        arch) pacman -Syu --noconfirm ;;
    esac
}

# Charm repository (gum isn't in the debian-like repositories)
setup_charm_repo() {
    command -v gpg > /dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y gpg
    install -d -m 0755 /etc/apt/keyrings \
        && curl -fsSL "$CHARM_KEY_URL" | gpg --dearmor --yes -o /etc/apt/keyrings/charm.gpg \
        && echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] $CHARM_REPO_URL * *" > /etc/apt/sources.list.d/charm.list \
        && apt-get update
}

# Install packages (fedora names, translated for the family), the missing ones are reported and skipped
pkg_install() {
    local package
    local name
    local -a names=()

    for package in "$@"; do
        name=$(pkg_name "$package")
        if [[ -z "$name" ]]; then
            continue
        fi
        if [[ "$OS_FAMILY:$name" == "deb:gum" ]] && ! pkg_available gum; then
            setup_charm_repo > /dev/null || warning "Charm repository (gum) can't be added"
        fi
        if [[ "$package" == http* ]] || pkg_available "$name"; then
            names+=("$name")
        else
            warning "$name is not in the $OS_FAMILY repositories: skipped"
        fi
    done
    if [[ ${#names[@]} -eq 0 ]]; then
        return 0
    fi
    case "$OS_FAMILY" in
        rpm) dnf install -y "${names[@]}" ;;
        deb) DEBIAN_FRONTEND=noninteractive apt-get install -y "${names[@]}" ;;
        arch) pacman -S --needed --noconfirm "${names[@]}" ;;
    esac
}

# Install packages inside a box, return 1 on failure
install_packages() {
    local status=0

    box_open "DOWNLOAD-PACKAGE"
    pkg_install "$@" || status=1
    box_close "DOWNLOAD-PACKAGE"
    if [[ "$status" -ne 0 ]]; then
        failed "Download package ($*)"
        return 1
    fi
    ok "Download package"
}

# Run a step inside a box and report it, return 1 on failure: run_step <NAME> <label> <command...>
# (set -e is ignored inside the command -> chain its commands with &&)
run_step() {
    local name="$1"
    local label="$2"
    local status=0
    shift 2

    box_open "$name"
    "$@" || status=1
    box_close "$name"
    if [[ "$status" -ne 0 ]]; then
        failed "$label"
        return 1
    fi
    ok "$label"
}

# Run a command as the user who launched the setup through sudo
run_as_user() {
    sudo -u "$SUDO_USER" -H "$@"
}

# Install a file owned by root with a clean SELinux context (mv would keep the home context)
install_root_file() {
    local mode="$1"
    local src="$2"
    local dest="$3"

    install -D -o root -g root -m "$mode" "$src" "$dest"
    restorecon "$dest" 2> /dev/null || true
}

# Escape a value used as the replacement part of a sed substitution with '|' as separator
escape_sed() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

# Run the setup.sh of the ai-utils repository as the user (local clone of the Git setup, managed clone otherwise)
ai_utils_setup() {
    if [[ -f "$AI_UTILS_DIR/setup.sh" ]]; then
        run_as_user bash "$AI_UTILS_DIR/setup.sh" "$@"
    else
        run_as_user bash -c 'curl -fsSL "$0" | bash -s -- "$@"' "$AI_UTILS_SETUP_URL" "$@"
    fi
}

# Check that a usb with the given vendor-id and device-id is plugged
usb_is_plugged() {
    [[ -n "$1" && -n "$2" ]] && lsusb -d "$1:$2" > /dev/null 2>&1
}

# Lists of usb keys are written "<vendor-id>:<device-id>,<vendor-id>:<device-id>" (empty = no key)
# Check that at least one usb of a list is plugged
usbs_any_plugged() {
    local usb

    for usb in ${1//,/ }; do
        if lsusb -d "$usb" > /dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Check that a usb ("<vendor-id>:<device-id>") is in a list
usb_in_list() {
    local usb

    for usb in ${2//,/ }; do
        [[ "$usb" == "$1" ]] && return 0
    done
    return 1
}

# Check that no usb is in both lists (a key is either a main key or a cancel key): print the ones in both
usbs_overlap() {
    local usb
    local status=1

    for usb in ${1//,/ }; do
        if usb_in_list "$usb" "$2"; then
            echo "$usb"
            status=0
        fi
    done
    return "$status"
}

# =========================
# Checks
# =========================
# Family of the distribution: rpm (fedora-like), deb (debian-like), arch (arch-like)
os_family() {
    local id=""
    local id_like=""

    # shellcheck disable=SC1091
    id=$(. /etc/os-release && echo "${ID:-}")
    id_like=$(. /etc/os-release && echo "${ID_LIKE:-}")
    case " $id $id_like " in
        *" fedora "*|*" rhel "*|*" centos "*) echo "rpm" ;;
        *" debian "*|*" ubuntu "*) echo "deb" ;;
        *" arch "*) echo "arch" ;;
        *) echo "unknown" ;;
    esac
}

OS_FAMILY="${OS_FAMILY:-$(os_family)}"
OS_NAME=$(. /etc/os-release && echo "${PRETTY_NAME:-$ID}")
if [[ "$OS_FAMILY" == "unknown" ]]; then
    failed "Unsupported distribution ($OS_NAME): fedora-like, debian-like or arch-like only"
    exit 1
fi
if [[ $EUID -ne 0 || -z "${SUDO_USER:-}" || "${SUDO_USER:-}" == "root" ]]; then
    failed "The setup must be run with sudo from the user account (sudo make)"
    exit 1
fi
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# =========================
# Repositories
# =========================
GITHUB_USER="TsukiNi22"
AI_UTILS_DIR="$USER_HOME/personal_delivery/other/ai-utils" # Clone of the Git setup (base repositories)
CHARM_KEY_URL="https://repo.charm.sh/apt/gpg.key"
CHARM_REPO_URL="https://repo.charm.sh/apt/"
AI_UTILS_SETUP_URL="https://raw.githubusercontent.com/$GITHUB_USER/ai-utils/main/setup.sh"
