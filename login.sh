#!/usr/bin/env bash
set -euo pipefail

if [ -n "${REPO_USERNAME:-}" ] && [ -n "${REPO_PASSWORD:-}" ]; then
  echo "$REPO_PASSWORD" | buildah login -u "$REPO_USERNAME" --password-stdin quay.io
fi

USE_CACHE=
if [ -n "${CACHE_IMAGE:-}" ] && [ -n "${CACHE_USERNAME:-}" ] && [ -n "${CACHE_PASSWORD:-}" ]; then
  USE_CACHE=1
  echo "$CACHE_PASSWORD" | buildah login -u "$CACHE_USERNAME" --password-stdin ghcr.io
fi

export USE_CACHE
