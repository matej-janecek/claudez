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
  local docker_args=()
  local claude_args=()
  local image_name=""
  local use_docker=0
  local allow_root=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --image)
        shift
        image_name="${1:?Missing image name for --image}"
        shift
        ;;
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
      --docker)
        use_docker=1
        shift
        ;;
      --allow-root)
        allow_root=1
        shift
        ;;
      *)
        claude_args+=("$1")
        shift
        ;;
    esac
  done
  if [[ -f "$(pwd)/.claudez" ]]; then
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
      key="${key// /}"
      value="${value// /}"
      case "$key" in
        \#*|"") ;;
        image) [[ -z "$image_name" ]] && image_name="$value" ;;
        docker) [[ "$value" == "true" ]] && use_docker=1 ;;
        allow-root) [[ "$value" == "true" ]] && allow_root=1 ;;
      esac
    done < "$(pwd)/.claudez"
  fi
  if [[ "$use_docker" -eq 1 ]]; then
    local docker_sock="${DOCKER_HOST:-/var/run/docker.sock}"
    docker_sock="${docker_sock#unix://}"
    if [[ ! -S "$docker_sock" ]]; then
      echo "claudez: Docker socket not found at $docker_sock" >&2
      return 1
    fi
    if [[ "$(uname)" == "Darwin" ]]; then
      docker_args+=(-v "$docker_sock:/var/run/docker.sock" -e DOCKER_SOCK_GID="$(stat -f '%g' "$docker_sock")")
    else
      docker_args+=(-v "$docker_sock:/var/run/docker.sock" -e DOCKER_SOCK_GID="$(stat -c '%g' "$docker_sock")")
    fi
  fi
  image_name="${image_name:-claudez}"
  echo ""
  echo -e "\033[0;36m   image:\033[0m  $image_name"
  echo -e "\033[0;36m  docker:\033[0m  $([[ "$use_docker" -eq 1 ]] && echo "on" || echo "off")"
  [[ ${#extra_volumes[@]} -gt 0 ]] && echo -e "\033[0;36m volumes:\033[0m  ${extra_volumes[*]//-v /}"
  [[ ${#network_args[@]} -gt 0 ]] && echo -e "\033[0;36m network:\033[0m  ${network_args[*]//--network /}"
  echo ""
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
    "${docker_args[@]}" \
    -e HOME="$HOME" \
    -e HOST_UID="$(id -u)" \
    -e HOST_GID="$(id -g)" \
    -w "$(pwd)" \
    -e CLAUDE_CODE_SKIP_PERMISSIONS=1 \
    -e CLAUDEZ_ALLOW_ROOT="$allow_root" \
    -e DISPLAY="$DISPLAY" \
    $([[ -d /tmp/.X11-unix ]] && echo "-v /tmp/.X11-unix:/tmp/.X11-unix") \
    --add-host host.docker.internal:host-gateway \
    "$image_name" "${claude_args[@]}"
}
# claudez:end'

FISH_FUNC='# claudez:start
function claudez
  set -l extra_volumes
  set -l network_args
  set -l docker_args
  set -l claude_args
  set -l image_name ""
  set -l use_docker 0
  set -l allow_root 0
  set -l i 1
  while test $i -le (count $argv)
    if test "$argv[$i]" = "--image"
      set i (math $i + 1)
      set image_name $argv[$i]
    else if test "$argv[$i]" = "-v"
      set i (math $i + 1)
      set -l src (realpath -- $argv[$i] 2>/dev/null; or echo $argv[$i])
      set extra_volumes $extra_volumes -v "$src:$src"
    else if test "$argv[$i]" = "-n"
      set i (math $i + 1)
      set network_args $network_args --network $argv[$i]
    else if test "$argv[$i]" = "--docker"
      set use_docker 1
    else if test "$argv[$i]" = "--allow-root"
      set allow_root 1
    else
      set claude_args $claude_args $argv[$i]
    end
    set i (math $i + 1)
  end
  if test -f (pwd)/.claudez
    while read -l line
      set line (string trim -- $line)
      if string match -qr "^#" -- $line; or test -z "$line"
        continue
      end
      set -l key (string replace -r "=.*" "" -- $line | string trim)
      set -l value (string replace -r "[^=]*=" "" -- $line | string trim)
      if test "$key" = image; and test -z "$image_name"
        set image_name $value
      else if test "$key" = docker; and test "$value" = true
        set use_docker 1
      else if test "$key" = allow-root; and test "$value" = true
        set allow_root 1
      end
    end < (pwd)/.claudez
  end
  if test "$use_docker" -eq 1
    set -l docker_sock (set -q DOCKER_HOST; and echo $DOCKER_HOST; or echo /var/run/docker.sock)
    set docker_sock (string replace "unix://" "" -- $docker_sock)
    if not test -S "$docker_sock"
      echo "claudez: Docker socket not found at $docker_sock" >&2
      return 1
    end
    if test (uname) = "Darwin"
      set docker_args -v "$docker_sock:/var/run/docker.sock" -e DOCKER_SOCK_GID=(stat -f "%g" "$docker_sock")
    else
      set docker_args -v "$docker_sock:/var/run/docker.sock" -e DOCKER_SOCK_GID=(stat -c "%g" "$docker_sock")
    end
  end
  if test -z "$image_name"
    set image_name claudez
  end
  echo ""
  set_color cyan; echo -n "   image:"; set_color normal; echo "  $image_name"
  set_color cyan; echo -n "  docker:"; set_color normal; test "$use_docker" -eq 1; and echo "  on"; or echo "  off"
  if test (count $extra_volumes) -gt 0
    set_color cyan; echo -n " volumes:"; set_color normal; echo "  "(string replace -a -- "-v " "" "$extra_volumes")
  end
  if test (count $network_args) -gt 0
    set_color cyan; echo -n " network:"; set_color normal; echo "  "(string replace -a -- "--network " "" "$network_args")
  end
  echo ""
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
    $docker_args \
    -e HOME=$HOME \
    -e HOST_UID=(id -u) \
    -e HOST_GID=(id -g) \
    -w (pwd) \
    -e CLAUDE_CODE_SKIP_PERMISSIONS=1 \
    -e CLAUDEZ_ALLOW_ROOT=$allow_root \
    -e DISPLAY=$DISPLAY \
    (test -d /tmp/.X11-unix; and echo "-v /tmp/.X11-unix:/tmp/.X11-unix") \
    --add-host host.docker.internal:host-gateway \
    $image_name $claude_args
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
        sed '/^# claudez:start$/,/^# claudez:end$/d' "$rc_file" > "$rc_file.tmp" && mv "$rc_file.tmp" "$rc_file"
    elif grep -q '# claudez - isolated Claude Code container' "$rc_file" 2>/dev/null; then
        warn "${shell_name}: removing legacy claudez block from ${rc_file}..."
        sed '/# claudez - isolated Claude Code container/,/^}/d' "$rc_file" > "$rc_file.tmp" && mv "$rc_file.tmp" "$rc_file"
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
