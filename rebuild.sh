#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="claudez"

echo "Rebuilding ${IMAGE_NAME}..."
echo ""
docker build --no-cache -t "$IMAGE_NAME" "$SCRIPT_DIR"
echo ""
echo "Done."
