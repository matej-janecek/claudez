#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="claudez"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Install it first."
fi

# Build image
echo ""
echo "Building ${IMAGE_NAME} Docker image..."
echo ""
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
info "Docker image built successfully."

# Ensure config directories exist (prevents Docker creating them as root)
mkdir -p "$HOME/.claude" "$HOME/.config/claude-code" "$HOME/.local/share/claude" "$HOME/.local/state/claude"
[ -f "$HOME/.claude.json" ] || touch "$HOME/.claude.json"
info "Config directories ready."

# Shell function definitions
BASH_ZSH_FUNC='# claudez:start
claudez() {
  local extra_volumes=()
  local network_args=()
  local claude_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v)
        shift
        local src="${1:?Missing path for -v}"
        src="$(cd "$src" 2>/dev/null && pwd || echo "$src")"
        extra_volumes+=(-v "$src:$src")
        shift
        ;;
      -n)
        shift
        network_args+=(--network "${1:?Missing network name for -n}")
        shift
        ;;
      *)
        claude_args+=("$1")
        shift
        ;;
    esac
  done
  mkdir -p "$HOME/.local/share/claude" "$HOME/.local/state/claude"
  docker run -it --rm \
    -v "$(pwd)":"$(pwd)" \
    -v "$HOME/.claude:$HOME/.claude" \
    -v "$HOME/.claude.json:$HOME/.claude.json" \
    -v "$HOME/.config/claude-code:$HOME/.config/claude-code" \
    -v "$HOME/.local/share/claude:$HOME/.local/share/claude" \
    -v "$HOME/.local/state/claude:$HOME/.local/state/claude" \
    "${extra_volumes[@]}" \
    "${network_args[@]}" \
    -e HOME="$HOME" \
    -w "$(pwd)" \
    -e CLAUDE_CODE_SKIP_PERMISSIONS=1 \
    --add-host host.docker.internal:host-gateway \
    claudez "${claude_args[@]}"
}
# claudez:end'

FISH_FUNC='# claudez:start
function claudez
  set -l extra_volumes
  set -l network_args
  set -l claude_args
  set -l i 1
  while test $i -le (count $argv)
    if test "$argv[$i]" = "-v"
      set i (math $i + 1)
      set -l src (realpath -- $argv[$i] 2>/dev/null; or echo $argv[$i])
      set extra_volumes $extra_volumes -v "$src:$src"
    else if test "$argv[$i]" = "-n"
      set i (math $i + 1)
      set network_args $network_args --network $argv[$i]
    else
      set claude_args $claude_args $argv[$i]
    end
    set i (math $i + 1)
  end
  mkdir -p $HOME/.local/share/claude $HOME/.local/state/claude
  docker run -it --rm \
    -v (pwd):(pwd) \
    -v $HOME/.claude:$HOME/.claude \
    -v $HOME/.claude.json:$HOME/.claude.json \
    -v $HOME/.config/claude-code:$HOME/.config/claude-code \
    -v $HOME/.local/share/claude:$HOME/.local/share/claude \
    -v $HOME/.local/state/claude:$HOME/.local/state/claude \
    $extra_volumes \
    $network_args \
    -e HOME=$HOME \
    -w (pwd) \
    -e CLAUDE_CODE_SKIP_PERMISSIONS=1 \
    --add-host host.docker.internal:host-gateway \
    claudez $claude_args
end
# claudez:end'

install_shell_func() {
    local rc_file="$1"
    local func_body="$2"
    local shell_name="$3"

    if [ ! -f "$rc_file" ]; then
        touch "$rc_file"
    fi

    if grep -q '# claudez:start' "$rc_file" 2>/dev/null; then
        warn "${shell_name}: claudez already exists in ${rc_file}, replacing..."
        sed -i '/^# claudez:start$/,/^# claudez:end$/d' "$rc_file"
    elif grep -q '# claudez - isolated Claude Code container' "$rc_file" 2>/dev/null; then
        warn "${shell_name}: removing legacy claudez block from ${rc_file}..."
        sed -i '/# claudez - isolated Claude Code container/,/^}/d' "$rc_file"
    fi

    echo "$func_body" >> "$rc_file"
    info "${shell_name}: claudez added to ${rc_file}"
}

install_fish_func() {
    local fish_dir="$HOME/.config/fish"
    local func_file="$fish_dir/functions/claudez.fish"

    mkdir -p "$fish_dir/functions"

    if [ -f "$func_file" ]; then
        warn "Fish: claudez.fish already exists, replacing..."
    fi

    echo "$FISH_FUNC" > "$func_file"
    info "Fish: claudez saved to ${func_file}"
}

# Detect and install for available shells
INSTALLED=0

# Bash
if [ -n "$BASH_VERSION" ] || command -v bash &> /dev/null; then
    install_shell_func "$HOME/.bashrc" "$BASH_ZSH_FUNC" "Bash"
    INSTALLED=1
fi

# Zsh
if command -v zsh &> /dev/null; then
    install_shell_func "$HOME/.zshrc" "$BASH_ZSH_FUNC" "Zsh"
    INSTALLED=1
fi

# Fish
if command -v fish &> /dev/null; then
    install_fish_func
    INSTALLED=1
fi

if [ "$INSTALLED" -eq 0 ]; then
    error "No supported shell found (bash, zsh, fish)."
fi

echo ""
info "Installation complete!"
echo ""
echo "  Reload your shell or run:"
echo ""
command -v bash &> /dev/null && echo "    source ~/.bashrc"
command -v zsh &> /dev/null && echo "    source ~/.zshrc"
echo ""
echo "  Then cd into any project and run:"
echo ""
echo "    claudez"
echo ""
