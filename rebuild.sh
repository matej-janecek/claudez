#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="${1:-claudez}"
DOCKERFILE="${2:-$SCRIPT_DIR/Dockerfile}"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at ${DOCKERFILE}" >&2
    exit 1
fi

echo "Rebuilding ${IMAGE_NAME} from ${DOCKERFILE}..."
echo ""
docker build --no-cache -t "$IMAGE_NAME" -f "$DOCKERFILE" "$SCRIPT_DIR"
echo ""
echo "Done."
