#!/bin/bash
# Usage: sudo bash custom_package/launch.sh
# Install the custom packages & binaries: libutils (from the my-universe repositories, built from the
# sources on arch when they can't be used) and xstyle (built from the ai-utils repository)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

# Registers every package repository of my-universe (libutils, brain, context-forge...) for dnf / apt / pacman
UNIVERSE_SETUP_URL="https://${GITHUB_USER,,}.github.io/my-universe/install.sh"
LIBUTILS_REPO="https://github.com/$GITHUB_USER/libutils.git"
# Stable channel: optimized (op), debug (db) and asan (as) builds with their headers (dev)
LIBUTILS_PACKAGES=(libutils libutils-dev libutils-op libutils-dev-op libutils-db libutils-dev-db
    libutils-as libutils-dev-as)

# xstyle is built with clang++ and libutils
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

# Repositories of every package of my-universe (a repository already set up on its own is kept)
setup_universe() {
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

setup_libutils() {
    if setup_universe && pkg_install "${LIBUTILS_PACKAGES[@]}"; then
        return 0
    fi
    if [[ "$OS_FAMILY" == "arch" ]]; then
        warning "libutils can't be installed from the my-universe repositories: built from the sources"
        setup_libutils_sources
        return
    fi
    return 1
}

setup_xstyle() {
    ai_utils_setup install xstyle
}

# =========================
# Program
# =========================
CHOICES=$(ask_choose --multi --selected "libutils,xstyle" "Custom package & binary to install:" \
    "libutils" "xstyle") || CHOICES=""
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
