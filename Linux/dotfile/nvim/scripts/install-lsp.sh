#!/bin/sh
# Installs the language servers used by the Neovim config, for the user only (no root):
#   asm-lsp, lua-language-server, marksman, neocmakelsp -> ~/.local/bin (release binaries of GitHub)
#   pyright, bash-language-server, vscode-langservers-extracted, yaml-language-server -> npm global prefix (or ~/.local)
# clangd, nasm and shellcheck come from the package manager (dotfile/launch.sh of the dump repository).
# Run it again to update the versions written below.
set -eu

ASM_LSP=v0.10.1
LUA_LS=3.19.2
MARKSMAN=2026-02-08
NEOCMAKE=v0.12.0

bin="$HOME/.local/bin"
share="$HOME/.local/share"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$bin" "$share/lua-language-server"

fetch() { command curl -sSLf -o "$2" "$1"; }
gh_url() { echo "https://github.com/$1/releases/download/$2/$3"; }

echo "asm-lsp $ASM_LSP"
fetch "$(gh_url bergercookie/asm-lsp "$ASM_LSP" asm-lsp-x86_64-unknown-linux-gnu.tar.gz)" "$work/asm.tgz"
tar xzf "$work/asm.tgz" -C "$bin" asm-lsp

echo "neocmakelsp $NEOCMAKE"
asset=neocmakelsp-x86_64-unknown-linux-gnu
fetch "$(gh_url neocmakelsp/neocmakelsp "$NEOCMAKE" "$asset.tar.gz")" "$work/$asset.tar.gz"
fetch "$(gh_url neocmakelsp/neocmakelsp "$NEOCMAKE" "$asset.sha256")" "$work/$asset.sha256"
(cd "$work" && sha256sum -c "$asset.sha256")
tar xzf "$work/$asset.tar.gz" -C "$bin" neocmakelsp

echo "marksman $MARKSMAN"
fetch "$(gh_url artempyanykh/marksman "$MARKSMAN" marksman-linux-x64)" "$work/marksman"
install -m 755 "$work/marksman" "$bin/marksman"

echo "lua-language-server $LUA_LS"
fetch "$(gh_url LuaLS/lua-language-server "$LUA_LS" "lua-language-server-$LUA_LS-linux-x64.tar.gz")" "$work/lua.tgz"
rm -rf "$share/lua-language-server" && mkdir -p "$share/lua-language-server"
tar xzf "$work/lua.tgz" -C "$share/lua-language-server"
# Wrapper: the server finds its scripts next to the real binary
printf '#!/bin/sh\nexec "%s/lua-language-server/bin/lua-language-server" "$@"\n' "$share" > "$bin/lua-language-server"
chmod 755 "$bin/asm-lsp" "$bin/neocmakelsp" "$bin/lua-language-server"

echo "npm: pyright bash-language-server vscode-langservers-extracted yaml-language-server"
# The global prefix of npm is often /usr (root only): ~/.local then, its bin folder is in the PATH
prefix=$(npm config get prefix)
if [ ! -w "$prefix" ]; then prefix="$HOME/.local"; fi
npm install -g --prefix "$prefix" --no-fund --no-audit \
    pyright bash-language-server vscode-langservers-extracted yaml-language-server

for server in asm-lsp lua-language-server marksman neocmakelsp pyright-langserver bash-language-server \
    vscode-json-language-server yaml-language-server clangd; do
    printf '%-30s %s\n' "$server" "$(command -v "$server" || echo 'MISSING')"
done
