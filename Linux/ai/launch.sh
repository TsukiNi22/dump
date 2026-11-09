#!/bin/bash
# Usage: sudo bash ai/launch.sh
# Install the AI tools: Claude Code, Ollama, the skills (+ their tools) and the global context of the ai-utils repository
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils.sh"

CLAUDE_INSTALL_URL="https://claude.ai/install.sh"
OLLAMA_INSTALL_URL="https://ollama.com/install.sh"

# The tools of the skills (claude-cluster) are built with clang++ and libutils (Custom Package & Binary setup: universe)
install_packages gum git curl cmake make clang gcc-c++ python3 || exit 1

# =========================
# Setups
# =========================
# Native installer -> ~/.local/bin/claude (updates itself)
setup_claude() {
    if [[ -x "$USER_HOME/.local/bin/claude" ]]; then
        info "Claude Code already installed"
        return 0
    fi
    run_as_user bash -c 'curl -fsSL "$0" | bash' "$CLAUDE_INSTALL_URL"
}

# Official installer -> /usr/local/bin/ollama + ollama.service (re-run = update)
setup_ollama() {
    curl -fsSL "$OLLAMA_INSTALL_URL" | sh
}

# Every skill in ~/.claude/skills and the tools in ~/.local/bin
setup_skills() {
    ai_utils_setup install
}

# CLAUDE.md, RTK.md, hooks and rtk (branch 'context' of the ai-utils repository)
setup_context() {
    ai_utils_setup context install
}

# =========================
# Program
# =========================
CHOICES=$(ask_choose --multi --selected "Claude Code,Skills" "AI setup to run:" \
    "Claude Code" "Ollama" "Skills" "Skills context") || CHOICES=""
if [[ -z "$CHOICES" ]]; then
    skipped "AI setup"
    exit 0
fi

# mapfile: a setup reading stdin would eat the next choices of a while read loop
mapfile -t SELECTED <<< "$CHOICES"
status=0
for choice in "${SELECTED[@]}"; do
    case "$choice" in
        "Claude Code") run_step "SETUP-CLAUDE" "Setup of Claude Code" setup_claude || status=1 ;;
        "Ollama") run_step "SETUP-OLLAMA" "Setup of Ollama" setup_ollama || status=1 ;;
        "Skills") run_step "SETUP-SKILLS" "Setup of the skills" setup_skills || status=1 ;;
        "Skills context") run_step "SETUP-SKILLS-CONTEXT" "Setup of the skills context" setup_context || status=1 ;;
    esac
done
exit "$status"
