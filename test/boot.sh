#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGES_DIR="${REPO_ROOT}/_images"
BUILD_DIR="${REPO_ROOT}/build"

# Discover the build output subdirectory
BUILD_OUTPUT_DIR=$(find "${BUILD_DIR}" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | head -1)

if [ -z "${BUILD_OUTPUT_DIR}" ]; then
    echo "ERROR: No build output directory found under ${BUILD_DIR}"
    exit 1
fi

# Find the build config in the output directory
CONFIG_FILE="${BUILD_OUTPUT_DIR}/config.json"
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "ERROR: Build config not found at ${CONFIG_FILE}"
    exit 1
fi

echo "Booting image from: ${BUILD_OUTPUT_DIR}"
echo "Build config: ${CONFIG_FILE}"

# Boot the image and run validation checks.
# Run from the images directory so Go can find the module (go.mod) when
# boot-image builds cmd/check-host-config.
(cd "${IMAGES_DIR}" && ./test/scripts/boot-image "${BUILD_OUTPUT_DIR}" "${CONFIG_FILE}")
