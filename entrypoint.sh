#!/bin/bash

# Use the caller's UID:GID passed from the shell function.
# Falls back to stat on the working directory for backwards compatibility.
if [ -n "$HOST_UID" ] && [ -n "$HOST_GID" ]; then
    USER_ID="$HOST_UID:$HOST_GID"
else
    USER_ID="$(stat -c '%u:%g' "$(pwd)")"
    HOST_UID="${USER_ID%%:*}"
    HOST_GID="${USER_ID##*:}"
fi

if [ "$HOST_UID" -eq 0 ] && [ "${CLAUDEZ_ALLOW_ROOT:-0}" != "1" ]; then
    echo "ERROR: Refusing to run as root (UID 0). This would break host config ownership." >&2
    echo "       Use --allow-root flag or set allow-root=true in .claudez to override." >&2
    exit 1
fi

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

# Docker socket group: add the user to a group matching the host's docker socket GID
if [ -n "$DOCKER_SOCK_GID" ]; then
    DOCKER_GROUP="$(getent group "$DOCKER_SOCK_GID" 2>/dev/null | cut -d: -f1)"
    if [ -z "$DOCKER_GROUP" ]; then
        groupadd -g "$DOCKER_SOCK_GID" docker 2>/dev/null
        DOCKER_GROUP="docker"
    fi
    USERNAME="$(getent passwd "$HOST_UID" | cut -d: -f1)"
    usermod -aG "$DOCKER_GROUP" "$USERNAME"
fi

# Resolve username for gosu so it calls initgroups() and applies supplementary groups
GOSU_USER="$(getent passwd "$HOST_UID" | cut -d: -f1)"

# Ensure home and config directories exist with correct ownership
mkdir -p "$HOME/.claude" "$HOME/.config/claude-code" "$HOME/.local/state/claude" "$HOME/.local/share/claude"
touch "$HOME/.claude.json"

# Fix ownership of HOME and ALL intermediate directories (Docker creates them as root)
chown "$USER_ID" "$HOME" "$HOME/.config" "$HOME/.local" "$HOME/.local/state" "$HOME/.local/share"
chown -R "$USER_ID" "$HOME/.claude" "$HOME/.claude.json" "$HOME/.config/claude-code" \
    "$HOME/.local/state/claude" "$HOME/.local/share/claude"

# Build skip-permissions flag from env var
SKIP_PERMS=()
if [ "${CLAUDE_CODE_SKIP_PERMISSIONS:-0}" = "1" ]; then
    SKIP_PERMS=(--dangerously-skip-permissions)
fi

# Use the host's native binary if available (avoids npm launcher onboarding mismatch)
NATIVE_BIN="$(ls -v "$HOME/.local/share/claude/versions/" 2>/dev/null | tail -1)"
if [ -n "$NATIVE_BIN" ] && [ -x "$HOME/.local/share/claude/versions/$NATIVE_BIN" ]; then
    # Native binary expects itself at ~/.local/bin/claude (same as host symlink)
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.local/share/claude/versions/$NATIVE_BIN" "$HOME/.local/bin/claude"
    chown -h "$USER_ID" "$HOME/.local/bin" "$HOME/.local/bin/claude"
    export PATH="$HOME/.local/bin:$PATH"
    exec gosu "$GOSU_USER" "$HOME/.local/share/claude/versions/$NATIVE_BIN" "${SKIP_PERMS[@]}" "$@"
fi

# Fallback to npm-installed claude
exec gosu "$GOSU_USER" claude "${SKIP_PERMS[@]}" "$@"
