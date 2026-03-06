#!/usr/bin/env bash
set -xeuo pipefail

# Create and push a multi-arch manifest. Required variables:
#
#   IMAGE, TAG, ARCHES (space-separated)
#
# Optional variables:
#
#   REPO_USERNAME, REPO_PASSWORD - destination registry credentials (skip push if missing)
#   CACHE_IMAGE, CACHE_USERNAME, CACHE_PASSWORD - sidecar cache registry (optional)
#   DRY_RUN - when set, skip all push operations (e.g. set for PR builds)

TO_REGISTRY=$(echo "$IMAGE" | cut -d/ -f1)
export TO_REGISTRY

. ./login.sh

echo "Creating manifest for $IMAGE:$TAG"
buildah manifest rm "$IMAGE:$TAG" 2>/dev/null || true
buildah manifest create "$IMAGE:$TAG"

for arch in $ARCHES; do
  if [ -n "${USE_CACHE:-}" ]; then
    echo "Pulling $CACHE_IMAGE:$TAG-$arch from cache"
    time buildah pull "docker://$CACHE_IMAGE:$TAG-$arch" || true
  fi

  if [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
    echo "Adding $IMAGE:$TAG-$arch to manifest (remote)"
    time buildah manifest add "$IMAGE:$TAG" "docker://$IMAGE:$TAG-$arch"
  else
    echo "Adding $IMAGE:$TAG-$arch to manifest (local)"
    time buildah manifest add "$IMAGE:$TAG" "$IMAGE:$TAG-$arch"
  fi
done

echo "Pushing manifest to $IMAGE:$TAG"
if [ -z "${DRY_RUN:-}" ] && [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  time buildah manifest push --all "$IMAGE:$TAG" "docker://$IMAGE:$TAG"
else
  echo "Push skipped: DRY_RUN is set or REPO_USERNAME or REPO_PASSWORD missing"
fi
