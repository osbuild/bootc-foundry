#!/usr/bin/env bash
set -xeuo pipefail

if [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  echo "Logging in to $TO_REGISTRY"
  echo "$REPO_PASSWORD" | buildah login -u "$REPO_USERNAME" --password-stdin "$TO_REGISTRY"
fi

USE_CACHE=
if [ -n "${CACHE_IMAGE:-}" ] && [ -n "${CACHE_USERNAME:-}" ] && [ -n "${CACHE_PASSWORD:-}" ]; then
  USE_CACHE=1
  CACHE_REGISTRY=$(echo "$CACHE_IMAGE" | cut -d/ -f1)
  echo "Logging in to $CACHE_REGISTRY (cache will be used)"
  echo "$CACHE_PASSWORD" | buildah login -u "$CACHE_USERNAME" --password-stdin "$CACHE_REGISTRY"
fi

export USE_CACHE
