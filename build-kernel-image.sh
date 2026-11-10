#!/usr/bin/env bash
# Build the UML kernel image (kernel-dist stage of Dockerfile) and
# optionally push it to Docker Hub as oldienki/uml-kernel-6.
#
# Usage:
#   ./build-kernel-image.sh            # build + tag locally
#   ./build-kernel-image.sh --push     # build, tag, and push to Docker Hub
#
# Env overrides:
#   KERNEL_IMAGE_REPO   target repo            (default: oldienki/uml-kernel-6)
#   KERNEL_VERSION      kernel version to build (default: 6.6.58)
#   KERNEL_SHA256       tarball sha256          (default: see Dockerfile)
#   EXTRA_TAGS          space-separated extra tags (default: "latest")

set -euo pipefail

# Self-contained build context — this directory is the whole repo.
CONTEXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="$CONTEXT_DIR/Dockerfile"

KERNEL_IMAGE_REPO=${KERNEL_IMAGE_REPO:-oldienki/uml-kernel-6}
KERNEL_VERSION=${KERNEL_VERSION:-6.6.58}
KERNEL_SHA256=${KERNEL_SHA256:-e7df81e588d70fab5ec3ec3bb04ac53d51f0860fc3b1ec45e0a4167a026899db}
EXTRA_TAGS=${EXTRA_TAGS:-latest}

PUSH=false
for arg in "$@"; do
    case "$arg" in
        --push) PUSH=true ;;
        -h|--help)
            sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

TAGS=("$KERNEL_IMAGE_REPO:$KERNEL_VERSION")
for t in $EXTRA_TAGS; do
    TAGS+=("$KERNEL_IMAGE_REPO:$t")
done

TAG_ARGS=()
for t in "${TAGS[@]}"; do
    TAG_ARGS+=(-t "$t")
done

echo "==> Building kernel-dist (linux $KERNEL_VERSION, ARCH=um)"
echo "    context: $CONTEXT_DIR"
printf '    tag: %s\n' "${TAGS[@]}"

docker build \
    --target kernel-dist \
    --build-arg "KERNEL_VERSION=$KERNEL_VERSION" \
    --build-arg "KERNEL_SHA256=$KERNEL_SHA256" \
    "${TAG_ARGS[@]}" \
    -f "$DOCKERFILE" \
    "$CONTEXT_DIR"

echo "==> Built ${TAGS[*]}"

if [ "$PUSH" = true ]; then
    for t in "${TAGS[@]}"; do
        echo "==> Pushing $t"
        docker push "$t"
    done
    echo "==> Pushed all tags to Docker Hub"
else
    echo "==> Skipping push (run with --push to publish to Docker Hub)"
fi
