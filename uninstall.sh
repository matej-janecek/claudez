#!/bin/bash
set -e

IMAGE_NAME="claudez"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

remove_from_rc() {
    local rc_file="$1"
    local shell_name="$2"

    if [ -f "$rc_file" ] && grep -q '# claudez:start' "$rc_file" 2>/dev/null; then
        sed -i '/^# claudez:start$/,/^# claudez:end$/d' "$rc_file"
        info "${shell_name}: removed from ${rc_file}"
    elif [ -f "$rc_file" ] && grep -q '# claudez - isolated Claude Code container' "$rc_file" 2>/dev/null; then
        sed -i '/# claudez - isolated Claude Code container/,/^}/d' "$rc_file"
        info "${shell_name}: removed legacy block from ${rc_file}"
    else
        warn "${shell_name}: not found in ${rc_file}, skipping"
    fi
}

# Remove from bash
remove_from_rc "$HOME/.bashrc" "Bash"

# Remove from zsh
remove_from_rc "$HOME/.zshrc" "Zsh"

# Remove from fish
FISH_FUNC="$HOME/.config/fish/functions/claudez.fish"
if [ -f "$FISH_FUNC" ]; then
    rm "$FISH_FUNC"
    info "Fish: removed ${FISH_FUNC}"
else
    warn "Fish: not found, skipping"
fi

# Remove Docker image
if docker image inspect "$IMAGE_NAME" &> /dev/null; then
    docker rmi "$IMAGE_NAME"
    info "Docker image ${IMAGE_NAME} removed"
else
    warn "Docker image ${IMAGE_NAME} not found, skipping"
fi

echo ""
info "Uninstall complete. Reload your shell to apply changes."
