#!/bin/bash
# Usage: sudo bash custom_package/launch.sh
# Install the custom packages of TsukiNi22 (my-universe): universe (the public package repositories + libutils, built
# from the sources on arch when they can't be used), xstyle (package, else built from its repository) and xdesk
# (private: gh auth of the user, its gh-pages mirrored like the universe CLI does)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

# Registers every public package repository of my-universe (libutils, brain, context-forge, xstyle...) for dnf / apt / pacman
UNIVERSE_SETUP_URL="https://${GITHUB_USER,,}.github.io/my-universe/install.sh"
LIBUTILS_REPO="https://github.com/$GITHUB_USER/libutils.git"
XSTYLE_REPO="https://github.com/$GITHUB_USER/xstyle.git"
XDESK_REPO="$GITHUB_USER/xdesk"
# Stable channel: optimized (op), debug (db) and asan (as) builds with their headers (dev)
LIBUTILS_PACKAGES=(libutils libutils-dev libutils-op libutils-dev-op libutils-db libutils-dev-db
    libutils-as libutils-dev-as)
# Mirrors of the private repositories: the same folder as the universe CLI (./universe mirror)
MIRROR_DIR="$USER_HOME/.local/share/universe"

# The source builds (libutils on arch, xstyle) need clang++, cmake and openssl
install_packages gum git curl gpg cmake make clang gcc-c++ python3 openssl-devel || exit 1

# =========================
# Setups
# =========================
# Repositories of my-universe already set up for this family
universe_repo_ready() {
    case "$OS_FAMILY" in
        rpm) [[ -f /etc/yum.repos.d/universe.repo ]] ;;
        deb) [[ -f /etc/apt/sources.list.d/universe.list ]] ;;
        arch) grep -q '^\[libutils\]' /etc/pacman.conf ;;
    esac
}

# Repositories of every public package of my-universe (a repository already set up on its own is kept)
setup_universe_repos() {
    if universe_repo_ready; then
        [[ "$OS_FAMILY" != "deb" ]] || apt-get update # install.sh only refreshes what it adds
        return
    fi
    curl -fsSL "$UNIVERSE_SETUP_URL" | bash -s -- --no-sudo
}

# Fallback of arch: Debug + Asan + Optimized builds from the sources into /usr/local
setup_libutils_sources() {
    local build_dir

    build_dir=$(mktemp -d)
    git clone -q --depth 1 "$LIBUTILS_REPO" "$build_dir/libutils" \
        && cmake -S "$build_dir/libutils" -B "$build_dir/libutils/build" \
        && cmake --build "$build_dir/libutils/build" --target install_release --parallel "$(nproc)"
    local status=$?
    rm -rf "$build_dir"
    return "$status"
}

# The public repositories, then libutils (every build)
setup_universe() {
    if setup_universe_repos && pkg_install "${LIBUTILS_PACKAGES[@]}"; then
        return 0
    fi
    if [[ "$OS_FAMILY" == "arch" ]]; then
        warning "libutils can't be installed from the my-universe repositories: built from the sources"
        setup_libutils_sources
        return
    fi
    return 1
}

# Package xstyle of my-universe, else built from its repository into /usr/local (needs libutils)
setup_xstyle() {
    local build_dir

    setup_universe_repos || warning "my-universe repositories can't be set up: xstyle built from the sources"
    if pkg_available xstyle; then
        pkg_install xstyle
        return
    fi
    warning "no xstyle package for $OS_FAMILY yet: built from $XSTYLE_REPO"
    if ! pkg_available libutils-dev && [[ ! -d /usr/local/include/utils ]]; then
        setup_universe || return 1
    fi
    build_dir=$(mktemp -d)
    git clone -q --depth 1 "$XSTYLE_REPO" "$build_dir/xstyle" \
        && cmake -S "$build_dir/xstyle" -B "$build_dir/xstyle/build" -DCMAKE_BUILD_TYPE=Optimized \
        && cmake --build "$build_dir/xstyle/build" --parallel "$(nproc)" \
        && cmake --install "$build_dir/xstyle/build" --prefix /usr/local
    local status=$?
    rm -rf "$build_dir"
    return "$status"
}

# gh logged in for the user (read access to the private repositories)
gh_ready() {
    command -v gh > /dev/null && run_as_user gh auth status > /dev/null 2>&1
}

# Root file written from the standard input (0644, SELinux context restored)
write_root_file() {
    tee "$1" > /dev/null && chmod 0644 "$1"
    restorecon "$1" 2> /dev/null || true
}

# Local repository of a private mirror (file://), for the package manager of the family; 1 when it holds no package
register_mirror() {
    local name="$1"
    local dir="$2"

    case "$OS_FAMILY" in
        rpm)
            [[ -d "$dir/fedora" ]] || return 1
            write_root_file /etc/yum.repos.d/universe-private.repo <<REPO
[universe-$name]
name=my-universe - $name (private mirror)
baseurl=file://$dir/fedora/\$releasever/\$basearch
enabled=1
gpgcheck=1
gpgkey=file://$dir/RPM-GPG-KEY-tsukini
REPO
            ;;
        deb)
            [[ -d "$dir/debian/dists" ]] || return 1
            install -m 0755 -d /etc/apt/keyrings
            gpg --dearmor --yes -o /etc/apt/keyrings/universe-private.gpg < "$dir/RPM-GPG-KEY-tsukini"
            echo "deb [signed-by=/etc/apt/keyrings/universe-private.gpg] file://$dir/debian stable main" \
                | write_root_file /etc/apt/sources.list.d/universe-private.list
            apt-get update
            ;;
        arch)
            [[ -d "$dir/arch" ]] || return 1
            pacman-key --add "$dir/RPM-GPG-KEY-tsukini" && pacman-key --lsign-key "$(gpg --show-keys --with-colons "$dir/RPM-GPG-KEY-tsukini" | awk -F: '/^fpr/ {print $10; exit}')"
            grep -q "^\[$name\]" /etc/pacman.conf || printf '\n[%s]\nSigLevel = Required\nServer = file://%s/arch/$arch\n' "$name" "$dir" >> /etc/pacman.conf
            pacman -Sy
            ;;
    esac
}

# Private: gh auth of the user (asked), its gh-pages mirrored, then registered and installed
setup_xdesk() {
    local answer
    local dir="$MIRROR_DIR/xdesk"

    command -v gh > /dev/null || pkg_install gh
    if ! gh_ready; then
        answer=$(ask_choose "xdesk is private: set up gh auth (GitHub login of $SUDO_USER)?" "Yes" "No") || answer="No"
        if [[ "$answer" == "Yes" ]]; then
            run_on_tty "GitHub login of $SUDO_USER (gh auth login)" sudo -u "$SUDO_USER" -H gh auth login --git-protocol ssh --web || true
        fi
    fi
    if ! gh_ready; then
        warning "xdesk is a private repository: without gh auth its packages can't be read (missing permissions), skipped"
        return 1
    fi
    run_as_user mkdir -p "$MIRROR_DIR"
    if [[ -d "$dir/.git" ]]; then
        run_as_user git -C "$dir" pull -q --ff-only || return 1
    else
        run_as_user gh repo clone "$XDESK_REPO" "$dir" -- -q --depth 1 --branch gh-pages || {
            warning "$XDESK_REPO can't be cloned (no access to the private repository with this gh account?)"
            return 1
        }
    fi
    if ! register_mirror xdesk "$dir"; then
        warning "no xdesk package on its gh-pages for $OS_FAMILY yet: only mirrored in $dir"
        return 0
    fi
    pkg_install xdesk
}

# =========================
# Program
# =========================
CHOICES=$(ask_choose --multi --selected "universe,xstyle" "Custom package & binary to install:" \
    "universe" "xstyle" "xdesk") || CHOICES=""
if [[ -z "$CHOICES" ]]; then
    skipped "Custom package & binary"
    exit 0
fi

# mapfile: a setup reading stdin would eat the next choices of a while read loop
mapfile -t SELECTED <<< "$CHOICES"
status=0
for choice in "${SELECTED[@]}"; do
    run_step "SETUP-${choice^^}" "Setup of $choice" "setup_$choice" || status=1
done
exit "$status"
