#!/usr/bin/env bash
set -euo pipefail

# Build and push a single-arch image. All inputs via environment variables:
#   REPO_USERNAME, REPO_PASSWORD  - optional; quay.io login (if missing, skips all push)
#   CACHE_URL, CACHE_USERNAME, CACHE_PASSWORD - optional; all three required for any cache use
#   TO_IMAGE, TO_TAG, ARCH, CONTAINERFILE, FROM_IMAGE, FROM_TAG - build params

if [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  echo "$REPO_PASSWORD" | buildah login -u "$REPO_USERNAME" --password-stdin quay.io
fi

USE_CACHE=
if [ -n "${CACHE_URL:-}" ] && [ -n "${CACHE_USERNAME:-}" ] && [ -n "${CACHE_PASSWORD:-}" ]; then
  USE_CACHE=1
  echo "$CACHE_PASSWORD" | buildah login -u "$CACHE_USERNAME" --password-stdin ghcr.io
fi

IMAGE="${TO_IMAGE}:${TO_TAG}-${ARCH}"
if [ -n "${USE_CACHE:-}" ]; then
  CACHE_IMAGE="${CACHE_URL}:${TO_TAG}-${ARCH}"
  buildah pull "$CACHE_IMAGE" 2>/dev/null || true
fi
buildah rmi "$IMAGE" 2>/dev/null || true

echo "Preparing Containerfile with FROM ${FROM_IMAGE}:${FROM_TAG}"
cp "Containerfile.comment" "Containerfile"
echo "FROM ${FROM_IMAGE}:${FROM_TAG}" >> "Containerfile"
tail -n +2 "Containerfile.${CONTAINERFILE}" >> "Containerfile"

echo "Building $IMAGE"
buildah build --layers --arch="$ARCH" \
  --build-arg CONTAINERFILE="Containerfile" \
  --from "${FROM_IMAGE}:${FROM_TAG}" \
  -f "Containerfile.${CONTAINERFILE}" \
  -t "$IMAGE" .

if [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  buildah push "$IMAGE"
else
  echo "Push skipped: REPO_USERNAME or REPO_PASSWORD missing"
fi

if [ -n "${USE_CACHE:-}" ]; then
  buildah push "$IMAGE" "$CACHE_IMAGE"
fi
