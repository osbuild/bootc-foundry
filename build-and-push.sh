#!/usr/bin/env bash
set -euo pipefail

# Build and push a single-arch image. All inputs via environment variables:
#   REPO_USERNAME, REPO_PASSWORD  - optional; quay.io login (if missing, skips all push)
#   CACHE_URL, CACHE_USERNAME, CACHE_PASSWORD - optional; all three required for any cache use
#   CACHE_ARCHIVE - optional; path to a tar file: load base image from it if present, save base to it after successful build
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

FROM_REF="${FROM_IMAGE}:${FROM_TAG}"
if [ -n "${CACHE_ARCHIVE:-}" ] && [ -f "$CACHE_ARCHIVE" ]; then
  echo "Loading base image from cache archive $CACHE_ARCHIVE"
  skopeo copy "docker-archive:$CACHE_ARCHIVE" "containers-storage:$FROM_REF"
fi

echo "Preparing Containerfile with FROM ${FROM_REF}"
cp "Containerfile.comment" "Containerfile"
echo "FROM ${FROM_REF}" >> "Containerfile"
tail -n +2 "Containerfile.${CONTAINERFILE}" >> "Containerfile"

if [ -n "${BUILDAH_ISOLATION:-}" ]; then
  EXTRA_BUILD_ARGS="--isolation=$BUILDAH_ISOLATION"
fi

echo "Building $IMAGE"
buildah build $EXTRA_BUILD_ARGS --layers --arch="$ARCH" \
  --build-arg CONTAINERFILE="Containerfile" \
  --from "${FROM_REF}" \
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

if [ -n "${CACHE_ARCHIVE:-}" ]; then
  echo "Saving base image to cache archive $CACHE_ARCHIVE"
  mkdir -p "$(dirname "$CACHE_ARCHIVE")"
  skopeo copy "containers-storage:$FROM_REF" "docker-archive:$CACHE_ARCHIVE"
fi
