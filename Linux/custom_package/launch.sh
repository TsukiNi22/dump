#!/bin/bash
# Usage: sudo bash custom_package/launch.sh
# Install the custom packages of TsukiNi22 (my-universe): universe (the package repositories + libutils, built from the
# sources on arch when they can't be used), xstyle (package, else built from its repository) and xdesk (package)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

# Registers every package repository of my-universe (libutils, brain, context-forge, xstyle, xdesk...) for dnf / apt / pacman
UNIVERSE_SETUP_URL="https://${GITHUB_USER,,}.github.io/my-universe/install.sh"
LIBUTILS_REPO="https://github.com/$GITHUB_USER/libutils.git"
XSTYLE_REPO="https://github.com/$GITHUB_USER/xstyle.git"
# Stable channel: optimized (op), debug (db) and asan (as) builds with their headers (dev)
LIBUTILS_PACKAGES=(libutils libutils-dev libutils-op libutils-dev-op libutils-db libutils-dev-db
    libutils-as libutils-dev-as)

# The source builds (libutils on arch, xstyle) need clang++, cmake and openssl
install_packages gum git curl gpg cmake make clang gcc-c++ python3 openssl-devel || exit 1

# =========================
# Setups
# =========================
# Repositories of every package of my-universe, run again each time: install.sh rewrites its own files with the packages
# added since (a repository already set up on its own is kept)
setup_universe_repos() {
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

# Package xdesk of my-universe (no source fallback: its build needs Qt6 and more, see its README)
setup_xdesk() {
    setup_universe_repos || warning "my-universe repositories can't be set up"
    if ! pkg_available xdesk; then
        warning "no xdesk package for $OS_FAMILY: see https://github.com/$GITHUB_USER/xdesk#quick-setup---1-all"
        return 1
    fi
    pkg_install xdesk
}

# =========================
# Program
# =========================
CHOICES=$(ask_choose --multi --selected "universe,xstyle,xdesk" "Custom package & binary to install:" \
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
