#!/usr/bin/env bash
set -euo pipefail

# Create and push a multi-arch manifest. All inputs via environment variables:
#   REPO_USERNAME, REPO_PASSWORD  - quay.io login (optional; no push if missing)
#   CACHE_URL, CACHE_USERNAME, CACHE_PASSWORD - optional; all three required for cache pull
#   IMAGE, TAG, ARCHES - manifest params (ARCHES is space-separated)

if [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  echo "$REPO_PASSWORD" | buildah login -u "$REPO_USERNAME" --password-stdin quay.io
fi

USE_CACHE=
if [ -n "${CACHE_URL:-}" ] && [ -n "${CACHE_USERNAME:-}" ] && [ -n "${CACHE_PASSWORD:-}" ]; then
  USE_CACHE=1
  echo "$CACHE_PASSWORD" | buildah login -u "$CACHE_USERNAME" --password-stdin ghcr.io
fi

echo "Creating manifest for $IMAGE:$TAG"
buildah manifest rm "$IMAGE:$TAG" 2>/dev/null || true
buildah manifest create "$IMAGE:$TAG"

# When credentials are missing we're running locally: images exist only in local storage.
# When credentials are set (e.g. GHA) we're in CI: images were pushed by build jobs, use remote refs.
USE_REMOTE_REFS=
if [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  USE_REMOTE_REFS=1
fi

for arch in $ARCHES; do
  if [ -n "${USE_CACHE:-}" ]; then
    echo "Pulling $CACHE_URL:$TAG-$arch from cache"
    buildah pull "docker://$CACHE_URL:$TAG-$arch" 2>/dev/null || true
  fi

  if [ -n "${USE_REMOTE_REFS:-}" ]; then
    echo "Adding $IMAGE:$TAG-$arch to manifest (remote)"
    buildah manifest add "$IMAGE:$TAG" "docker://$IMAGE:$TAG-$arch"
  else
    echo "Adding $IMAGE:$TAG-$arch to manifest (local)"
    buildah manifest add "$IMAGE:$TAG" "$IMAGE:$TAG-$arch"
  fi
done

echo "Pushing manifest to $IMAGE:$TAG"
if [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  buildah manifest push --all "$IMAGE:$TAG" "docker://$IMAGE:$TAG"
else
  echo "Push skipped: REPO_USERNAME or REPO_PASSWORD missing"
fi
