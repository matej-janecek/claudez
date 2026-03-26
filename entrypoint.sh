#!/bin/bash

# Detect host user's UID:GID from the mounted working directory
USER_ID="$(stat -c '%u:%g' "$(pwd)")"
HOST_UID="${USER_ID%%:*}"
HOST_GID="${USER_ID##*:}"

# Ensure /etc/passwd entry for this UID points to the correct HOME.
# The ubuntu:24.04 image ships a "ubuntu" user at UID 1000 with home /home/ubuntu,
# which causes the native binary to look for config there instead of $HOME.
EXISTING_USER="$(getent passwd "$HOST_UID" 2>/dev/null | cut -d: -f1)"
if [ -n "$EXISTING_USER" ]; then
    usermod -d "$HOME" -s /bin/bash "$EXISTING_USER" 2>/dev/null
else
    if ! getent group "$HOST_GID" > /dev/null 2>&1; then
        groupadd -g "$HOST_GID" hostuser 2>/dev/null
    fi
    useradd -u "$HOST_UID" -g "$HOST_GID" -d "$HOME" -s /bin/bash -M hostuser 2>/dev/null
fi

# Ensure home and config directories exist with correct ownership
mkdir -p "$HOME/.claude" "$HOME/.config/claude-code" "$HOME/.local/state/claude" "$HOME/.local/share/claude"
touch "$HOME/.claude.json"

# Fix ownership of HOME and ALL intermediate directories (Docker creates them as root)
chown "$USER_ID" "$HOME" "$HOME/.config" "$HOME/.local" "$HOME/.local/state" "$HOME/.local/share"
chown -R "$USER_ID" "$HOME/.claude" "$HOME/.claude.json" "$HOME/.config/claude-code" \
    "$HOME/.local/state/claude" "$HOME/.local/share/claude"

# Use the host's native binary if available (avoids npm launcher onboarding mismatch)
NATIVE_BIN="$(ls -v "$HOME/.local/share/claude/versions/" 2>/dev/null | tail -1)"
if [ -n "$NATIVE_BIN" ] && [ -x "$HOME/.local/share/claude/versions/$NATIVE_BIN" ]; then
    # Native binary expects itself at ~/.local/bin/claude (same as host symlink)
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.local/share/claude/versions/$NATIVE_BIN" "$HOME/.local/bin/claude"
    chown -h "$USER_ID" "$HOME/.local/bin" "$HOME/.local/bin/claude"
    export PATH="$HOME/.local/bin:$PATH"
    exec gosu "$USER_ID" "$HOME/.local/share/claude/versions/$NATIVE_BIN" "$@"
fi

# Fallback to npm-installed claude
exec gosu "$USER_ID" claude "$@"
