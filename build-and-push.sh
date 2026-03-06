#!/usr/bin/env bash
set -euo pipefail

#
# Build and push a single-arch image. Required variables:
#
#   TO_IMAGE, TO_TAG, ARCH, CONTAINERFILE, FROM_IMAGE, FROM_TAG
#
# Optional variables:
#
#   REPO_USERNAME, REPO_PASSWORD - destination registry credentials (skip push if missing)
#   CACHE_IMAGE, CACHE_USERNAME, CACHE_PASSWORD - sidecar cache registry (optional)
#   DRY_RUN - when set, skip all push operations (e.g. set for PR builds)

IMAGE="${TO_IMAGE}:${TO_TAG}-${ARCH}"

./login.sh

if [ -n "${USE_CACHE:-}" ]; then
  CACHE_IMAGE_FULL="${CACHE_IMAGE}:${TO_TAG}-${ARCH}"
  echo "Pulling cache image $CACHE_IMAGE_FULL"
  buildah pull "$CACHE_IMAGE_FULL" 2>/dev/null || true
fi
buildah rmi "$IMAGE" 2>/dev/null || true

FROM_REF="${FROM_IMAGE}:${FROM_TAG}"
echo "Preparing Containerfile with FROM ${FROM_REF}"
cp "Containerfile.comment" "Containerfile"
echo "FROM ${FROM_REF}" >> "Containerfile"
tail -n +2 "Containerfile.${CONTAINERFILE}" >> "Containerfile"

echo "Building $IMAGE"
buildah build --layers --arch="$ARCH" \
  --build-arg CONTAINERFILE="Containerfile" \
  --from "${FROM_REF}" \
  -f "Containerfile.${CONTAINERFILE}" \
  -t "$IMAGE" .

if [ -z "${DRY_RUN:-}" ] && [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  buildah push "$IMAGE"
else
  echo "Push skipped: DRY_RUN is set or REPO_USERNAME or REPO_PASSWORD missing"
fi

if [ -z "${DRY_RUN:-}" ] && [ -n "${USE_CACHE:-}" ]; then
  buildah push "$IMAGE" "$CACHE_IMAGE_FULL"
elif [ -n "${DRY_RUN:-}" ] && [ -n "${USE_CACHE:-}" ]; then
  echo "Push skipped: DRY_RUN is set or REPO_USERNAME or REPO_PASSWORD missing"
fi
