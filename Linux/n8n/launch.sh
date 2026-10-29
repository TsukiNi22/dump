#!/bin/bash
# Usage: sudo bash n8n/launch.sh
# (asks to activate or deactivate n8n)
# n8n workflow automation as a rootless podman container run by a systemd user service (quadlet), http://localhost:5678
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

SERVICE="n8n.service"
QUADLET="n8n.container"
QUADLET_DIR="$USER_HOME/.config/containers/systemd"
USER_ID=$(id -u "$SUDO_USER")

install_packages gum podman || exit 1

# systemctl --user of the user who launched the setup
user_systemctl() {
    run_as_user env XDG_RUNTIME_DIR="/run/user/$USER_ID" systemctl --user "$@"
}

activate() {
    run_as_user mkdir -p "$QUADLET_DIR"
    run_as_user cp "$SCRIPT_DIR/$QUADLET" "$QUADLET_DIR/$QUADLET"
    ok "Quadlet $QUADLET installed"

    # The user systemd instance exists when the user is logged in (or lingering)
    if [[ ! -d "/run/user/$USER_ID" ]]; then
        skipped "Service start (no user session: it starts at the next login)"
        return 0
    fi
    user_systemctl daemon-reload || return 1
    # The image is pulled by the first start (TimeoutStartSec=900)
    user_systemctl start "$SERVICE" || return 1
    ok "n8n started on http://localhost:5678"
}

deactivate() {
    user_systemctl stop "$SERVICE" 2> /dev/null || true
    rm -f "$QUADLET_DIR/$QUADLET"
    user_systemctl daemon-reload 2> /dev/null || true
    ok "n8n service removed (the volume n8n_data keeps the workflows)"
}

CHOICE=$(ask_choose "n8n:" "Activate" "Deactivate") || CHOICE="Cancel"
case "$CHOICE" in
    "Activate") run_step "SETUP-N8N" "Setup of n8n" activate ;;
    "Deactivate") deactivate ;;
    *) skipped "n8n setup" ;;
esac
