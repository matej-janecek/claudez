#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

BACKUP_DIR="${1:-$HOME/claude-backups}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/claude_backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

SOURCES=()
[ -d "$HOME/.claude" ] && SOURCES+=("$HOME/.claude")
[ -f "$HOME/.claude.json" ] && SOURCES+=("$HOME/.claude.json")
[ -d "$HOME/.config/claude-code" ] && SOURCES+=("$HOME/.config/claude-code")

if [ ${#SOURCES[@]} -eq 0 ]; then
    error "No Claude directories found to back up."
fi

echo "Backing up:"
for src in "${SOURCES[@]}"; do
    echo "  $src"
done
echo ""

tar -czf "$BACKUP_FILE" "${SOURCES[@]}" 2>/dev/null

info "Backup saved to $BACKUP_FILE"
info "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
