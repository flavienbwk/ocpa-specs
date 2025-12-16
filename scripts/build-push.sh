#!/bin/sh
# OCPA-R24: POSIX-compliant push script
# Tags and pushes images from compose.prod.yml to container registry
# Assumes images are already built via 'make prod-build'
#
# Usage: ./scripts/build-push.sh <registry> <repo> <tag> [sha_tag]
# Example: ./scripts/build-push.sh ghcr.io myorg/myrepo develop sha-abc1234

set -e

REGISTRY="${1:?ERROR: Registry required (e.g., ghcr.io)}"
REPO="${2:?ERROR: Repository required (e.g., myorg/myrepo)}"
TAG="${3:?ERROR: Tag required (e.g., develop, latest)}"
SHA_TAG="${4:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_DIR/compose.prod.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERROR: $COMPOSE_FILE not found"
    exit 1
fi

echo "INFO: Extracting services from $COMPOSE_FILE..."
# Extract service names (POSIX-compliant)
services=$(grep -E "^  [a-zA-Z0-9_-]+:" "$COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')

for service in $services; do
    # Get the built image name (project_service format)
    project_name=$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
    local_image="${project_name}-${service}"

    # Check if image exists
    if ! docker image inspect "$local_image" >/dev/null 2>&1; then
        echo "WARN: Image $local_image not found, skipping..."
        continue
    fi

    remote_image="$REGISTRY/$REPO/$service"

    echo "INFO: Tagging $local_image -> $remote_image:$TAG"
    docker tag "$local_image" "$remote_image:$TAG"

    if [ -n "$SHA_TAG" ]; then
        echo "INFO: Tagging $local_image -> $remote_image:$SHA_TAG"
        docker tag "$local_image" "$remote_image:$SHA_TAG"
    fi

    echo "INFO: Pushing $remote_image:$TAG"
    docker push "$remote_image:$TAG"

    if [ -n "$SHA_TAG" ]; then
        echo "INFO: Pushing $remote_image:$SHA_TAG"
        docker push "$remote_image:$SHA_TAG"
    fi

    echo "SUCCESS: Pushed $remote_image"
done

echo "SUCCESS: All images pushed"
