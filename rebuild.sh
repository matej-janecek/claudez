#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CACHE_FLAG=()
IMAGE_NAME=""
DOCKERFILE=""

for arg in "$@"; do
    case "$arg" in
        --no-cache) CACHE_FLAG=(--no-cache) ;;
        *)
            if [ -z "$IMAGE_NAME" ]; then
                IMAGE_NAME="$arg"
            else
                DOCKERFILE="$arg"
            fi
            ;;
    esac
done

IMAGE_NAME="${IMAGE_NAME:-claudez}"
DOCKERFILE="${DOCKERFILE:-$SCRIPT_DIR/Dockerfile}"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at ${DOCKERFILE}" >&2
    exit 1
fi

echo "Rebuilding ${IMAGE_NAME} from ${DOCKERFILE}..."
echo ""
docker build "${CACHE_FLAG[@]}" -t "$IMAGE_NAME" -f "$DOCKERFILE" "$SCRIPT_DIR"
echo ""
echo "Done."
