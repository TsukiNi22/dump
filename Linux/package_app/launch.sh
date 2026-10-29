#!/bin/bash
# Usage: sudo bash package_app/launch.sh
# Install the packages & apps (a failed step is reported and the next ones still run)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

RPM_FUSION_URL="https://download1.rpmfusion.org"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
VSCODE_KEY="https://packages.microsoft.com/keys/microsoft.asc"
VSCODE_KEYRING="/usr/share/keyrings/microsoft.gpg"
ASCIIQUARIUM_URL="https://raw.githubusercontent.com/cmatsuoka/asciiquarium/master/asciiquarium"
FAILED_STEPS=()

# Run a step, record it when it fails (the next steps still run)
step() {
    run_step "$@" || FAILED_STEPS+=("$2")
}

# =========================
# Steps
# =========================
# Commands chained with && (see run_step)
setup_rpm_fusion() {
    local version

    version=$(rpm -E %fedora)
    pkg_install \
        "$RPM_FUSION_URL/free/fedora/rpmfusion-free-release-$version.noarch.rpm" \
        "$RPM_FUSION_URL/nonfree/fedora/rpmfusion-nonfree-release-$version.noarch.rpm"
}

# Microsoft repository (fedora: yum, debian: apt), arch: code is in the official repositories
setup_vscode_repo() {
    case "$OS_FAMILY" in
        rpm)
            rpm --import "$VSCODE_KEY" && cat > /etc/yum.repos.d/vscode.repo <<VSCODE
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=$VSCODE_KEY
VSCODE
            ;;
        deb)
            curl -fsSL "$VSCODE_KEY" | gpg --dearmor --yes -o "$VSCODE_KEYRING" \
                && echo "deb [arch=amd64,arm64 signed-by=$VSCODE_KEYRING] https://packages.microsoft.com/repos/code stable main" \
                    > /etc/apt/sources.list.d/vscode.list \
                && apt-get update
            ;;
        arch) info "code is in the arch repositories" ;;
    esac
}

# From the repositories, else from its sources (debian: removed, arch: AUR only) with its perl modules
setup_asciiquarium() {
    local name

    name=$(pkg_name asciiquarium)
    if [[ -n "$name" ]] && pkg_available "$name"; then
        pkg_install asciiquarium
        return
    fi
    if ! perl -MTerm::Animation -MCurses -e 1 2> /dev/null; then
        case "$OS_FAMILY" in
            deb) pkg_install libterm-animation-perl libcurses-perl ;;
            arch) pkg_install perl make gcc ncurses ;;
        esac
    fi
    # Not in the repositories: built by cpan
    if ! perl -MTerm::Animation -MCurses -e 1 2> /dev/null; then
        PERL_MM_USE_DEFAULT=1 cpan -T Curses Term::Animation || return 1
    fi
    curl -fsSL -o /usr/local/bin/asciiquarium "$ASCIIQUARIUM_URL" && chmod 755 /usr/local/bin/asciiquarium
}

setup_wireshark() {
    # debian: allow the non-root captures (debconf question)
    if [[ "$OS_FAMILY" == "deb" ]]; then
        echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
    fi
    pkg_install wireshark && usermod -aG wireshark "$SUDO_USER"
}

setup_docker() {
    pkg_install moby-engine docker-compose \
        && systemctl enable --now docker \
        && usermod -aG docker "$SUDO_USER"
}

# GPU drivers and compute libraries chosen from the hardware found by lspci (nvidia, amd, intel)
setup_gpu() {
    local gpus
    local status=0

    pkg_install pciutils || return 1
    gpus=$(lspci -nn | grep -i -E "vga|3d|display" || true)
    if [[ -z "$gpus" ]]; then
        info "No GPU found"
        return 0
    fi
    if grep -qi "nvidia" <<< "$gpus"; then
        info "NVIDIA GPU: proprietary driver + CUDA (graphics, ollama, compute)"
        case "$OS_FAMILY" in
            rpm) pkg_install akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs || status=1 ;;
            deb) pkg_install nvidia-driver nvidia-cuda-toolkit nvidia-opencl-icd || status=1 ;;
            arch) pkg_install nvidia-dkms nvidia-utils cuda opencl-nvidia || status=1 ;;
        esac
    fi
    if grep -qi -E "amd|ati|radeon" <<< "$gpus"; then
        info "AMD GPU: mesa + vulkan + ROCm (compute, ollama)"
        case "$OS_FAMILY" in
            rpm) pkg_install mesa-vulkan-drivers mesa-dri-drivers rocm-opencl rocm-hip || status=1 ;;
            deb) pkg_install mesa-vulkan-drivers mesa-opencl-icd libdrm-amdgpu1 || status=1 ;;
            arch) pkg_install mesa vulkan-radeon rocm-hip-runtime rocm-opencl-runtime || status=1 ;;
        esac
    fi
    if grep -qi "intel" <<< "$gpus"; then
        info "Intel GPU: media driver + vulkan"
        case "$OS_FAMILY" in
            rpm) pkg_install intel-media-driver mesa-vulkan-drivers || status=1 ;;
            deb) pkg_install intel-media-va-driver mesa-vulkan-drivers || status=1 ;;
            arch) pkg_install intel-media-driver vulkan-intel || status=1 ;;
        esac
    fi
    return "$status"
}

# =========================
# Program
# =========================
step "BASE-PACKAGE" "Download base package" \
    pkg_install dnf-plugins-core flatpak git curl wget gpg tree ripgrep gh
step "ASCIIQUARIUM" "Setup of asciiquarium" setup_asciiquarium
if [[ "$OS_FAMILY" == "rpm" ]]; then
    step "SETUP-RPM-FUSION" "Setup RPM Fusion" setup_rpm_fusion
fi
step "SETUP-GPU" "Setup of the GPU drivers" setup_gpu
step "SETUP-FLATHUB" "Setup Flathub" \
    flatpak remote-add --if-not-exists flathub "$FLATHUB_URL"

# Used by the zshrc aliases (cmake/make/docker/valgrind/tmux/zenity/play/xeyes/upower)
step "DEV-TOOLS" "Download development tools" \
    pkg_install gcc gcc-c++ clang make cmake ccache gtest-devel valgrind python3 python3-pip \
        tmux zenity sox xeyes upower doxygen llvm perf dos2unix rpm-build rpm-sign createrepo_c \
        java-25-openjdk-devel k6
step "DEV-LIBS" "Download development libraries" \
    pkg_install lua-devel json-devel cpp-httplib-devel libsodium-devel libconfig-devel ncurses-devel \
        qt6-qtbase-devel
step "CLI-TOOLS" "Download command line tools" pkg_install htop nmap nmap-ncat rsync lrzsz glow android-tools
if [[ "$OS_FAMILY" == "rpm" ]]; then
    step "MINGW" "Download of the Windows cross compiler" \
        pkg_install mingw64-gcc-c++ mingw64-openssl mingw64-libutils mingw64-libutils-db
fi
step "SETUP-DOCKER" "Setup of docker" setup_docker
step "DOWNLOAD-CSFML" "Download of the csfml" pkg_install CSFML CSFML-devel
step "CYBER-SECURITY" "Download cyber security package" pkg_install binwalk gobuster hydra john
step "SETUP-WIRESHARK" "Setup of wireshark" setup_wireshark
step "VSCODE-REPO" "Setup of the vscode repository" setup_vscode_repo
step "VSCODE-SETUP" "Setup of vscode" pkg_install code

# fedora: telegram-desktop comes from RPM Fusion, debian-like: not in the repositories -> flatpak
if [[ "$OS_FAMILY" == "deb" ]]; then
    step "DESKTOP-APP" "Download of the desktop app" pkg_install qbittorrent
    step "TELEGRAM-FLATPAK" "Download of telegram (flatpak)" \
        flatpak install -y --noninteractive flathub org.telegram.desktop
else
    step "DESKTOP-APP" "Download of the desktop app" pkg_install telegram-desktop qbittorrent
fi
step "FLATPAK-APP" "Download of the flatpak app" \
    flatpak install -y --noninteractive flathub dev.vencord.Vesktop org.vinegarhq.Sober

if [[ ${#FAILED_STEPS[@]} -ne 0 ]]; then
    warning "Failed steps: ${FAILED_STEPS[*]}"
fi
info "Log out and in again to use the docker & wireshark groups"
