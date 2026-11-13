#!/bin/bash
# Usage: sudo bash dotfile/launch.sh
# Install the user config: zsh + oh-my-zsh, neovim, fastfetch, tmux, git ignore
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FASTFETCH_DEB_URL="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$(dpkg --print-architecture 2> /dev/null || echo amd64).deb"
OMZ_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# =========================
# Packages
# =========================
# tree-sitter-cli + gcc: build of the nvim-treesitter parsers, util-linux-user: chsh
# clang-tools-extra (clangd), nasm, ShellCheck, npm: language servers of nvim and the checks they run
install_packages vim-enhanced neovim git gcc tree-sitter-cli fastfetch chafa \
    zsh zoxide sl tmux curl util-linux-user wl-clipboard \
    clang-tools-extra nasm ShellCheck npm || exit 1

# fastfetch isn't in the old debian-like repositories (ex: ubuntu 24.04): official .deb of its releases
if ! command -v fastfetch > /dev/null && [[ "$OS_FAMILY" == "deb" ]]; then
    fastfetch_deb=$(mktemp --suffix=.deb)
    if curl -fsSL -o "$fastfetch_deb" "$FASTFETCH_DEB_URL" \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y "$fastfetch_deb"; then
        ok "Fastfetch installed from its github release"
    else
        warning "Fastfetch can't be installed: the fastfetch alias of the zshrc won't work"
    fi
    rm -f "$fastfetch_deb"
fi

# =========================
# Zsh
# =========================
# Before the zshrc copy: the installer would replace it otherwise
if [[ -d "$USER_HOME/.oh-my-zsh" ]]; then
    ok "Oh-My-Zsh already installed"
elif run_as_user env RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL "$OMZ_URL")" "" --unattended; then
    ok "Oh-My-Zsh setup"
else
    failed "Oh-My-Zsh setup"
    exit 1
fi

if [[ -f "$USER_HOME/.zshrc" ]] && ! cmp -s "$SCRIPT_DIR/.zshrc" "$USER_HOME/.zshrc"; then
    run_as_user cp "$USER_HOME/.zshrc" "$USER_HOME/.zshrc.bak"
    info "Old zshrc saved in ~/.zshrc.bak"
fi
run_as_user mkdir -p "$USER_HOME/.zsh/completions"
run_as_user cp "$SCRIPT_DIR/.zshrc" "$USER_HOME/.zshrc"

# The dump alias points to this repository, wherever it was cloned
run_as_user sed -i "s|^alias dump=.*|alias dump='\\\\sudo make -C \"$(escape_sed "$REPO_DIR")\"'|" "$USER_HOME/.zshrc"
ok "Zshrc setup (dump -> $REPO_DIR)"

if chsh -s "$(command -v zsh)" "$SUDO_USER" > /dev/null; then
    ok "Zsh is now the default shell"
else
    skipped "Zsh to default shell"
fi

# =========================
# Config files
# =========================
run_as_user mkdir -p "$USER_HOME/.config/git"
run_as_user cp -rf "$SCRIPT_DIR/nvim" "$USER_HOME/.config/"
ok "Neovim config setup"

# Optional shared library of the c2dmp matching (needs clang++ and libutils), without it nvim falls back to lua
if command -v clang++ > /dev/null && run_as_user sh "$USER_HOME/.config/nvim/native/build.sh" > /dev/null 2>&1; then
    ok "Neovim c2dmp library built"
else
    skipped "Neovim c2dmp library (clang++ or libutils missing)"
fi

# asm-lsp reads the NASM syntax (its errors come from nasm instead of gcc)
run_as_user mkdir -p "$USER_HOME/.config/asm-lsp"
run_as_user cp "$SCRIPT_DIR/asm-lsp/.asm-lsp.toml" "$USER_HOME/.config/asm-lsp/.asm-lsp.toml"
# Language servers of the user (asm, lua, python, bash, json, yaml, markdown, cmake): release binaries + npm
run_as_user chmod +x "$USER_HOME/.config/nvim/scripts/install-lsp.sh"
if run_as_user "$USER_HOME/.config/nvim/scripts/install-lsp.sh" > /dev/null 2>&1; then
    ok "Neovim language servers installed"
else
    skipped "Neovim language servers (download or npm failed: run ~/.config/nvim/scripts/install-lsp.sh)"
fi

# config.jsonc is generated from config_save.jsonc by rdm_img.sh (fastfetch alias)
run_as_user cp -rf "$SCRIPT_DIR/fastfetch" "$USER_HOME/.config/"
run_as_user chmod +x "$USER_HOME/.config/fastfetch/rdm_img.sh"
ok "Fastfetch config setup"

run_as_user cp "$SCRIPT_DIR/.tmux.conf" "$USER_HOME/.tmux.conf"
run_as_user mkdir -p "$USER_HOME/.config/tmux"
run_as_user cp "$SCRIPT_DIR/tmux/mode.sh" "$SCRIPT_DIR/tmux/scroll.sh" "$USER_HOME/.config/tmux/"
run_as_user chmod +x "$USER_HOME/.config/tmux/mode.sh" "$USER_HOME/.config/tmux/scroll.sh"
ok "Tmux config setup"

run_as_user cp "$SCRIPT_DIR/git/ignore" "$USER_HOME/.config/git/ignore"
ok "Git global ignore setup"
