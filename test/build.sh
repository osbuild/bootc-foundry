#!/bin/bash
set -euo pipefail

CONTAINER_IMAGE="${1:?Usage: build.sh <container-image> <image-type> <arch> <distro-id> [payload-container-image]}"
IMAGE_TYPE="${2:?Missing image-type argument}"
ARCH="${3:?Missing arch argument}"
DISTRO_ID="${4:?Missing distro-id argument}"
PAYLOAD_CONTAINER_IMAGE="${5:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGES_DIR="${REPO_ROOT}/_images"
BUILD_DIR="${REPO_ROOT}/build"
CONFIG_FILE="${BUILD_DIR}/config.json"

mkdir -p "${BUILD_DIR}"

# Build the config JSON. Start with the base, optionally inject the payload ref.
cat > "${CONFIG_FILE}" <<EOF
{
  "name": "bootc-foundry",
  "blueprint": {},
  "options": {
    "bootc": {}
  }
}
EOF

if [ -n "${PAYLOAD_CONTAINER_IMAGE}" ]; then
    TMP=$(jq --arg ref "${PAYLOAD_CONTAINER_IMAGE}" '.options.bootc.installer_payload_ref = $ref' "${CONFIG_FILE}")
    echo "${TMP}" > "${CONFIG_FILE}"
fi

echo "Build config:"
cat "${CONFIG_FILE}"

echo ""
echo "Building disk image:"
echo "  Container: ${CONTAINER_IMAGE}"
echo "  Image type: ${IMAGE_TYPE}"
echo "  Architecture: ${ARCH}"
echo "  Distro ID: ${DISTRO_ID}"
if [ -n "${PAYLOAD_CONTAINER_IMAGE}" ]; then
    echo "  Payload container: ${PAYLOAD_CONTAINER_IMAGE}"
fi

# Build the disk image using the images library's cmd/build.
# Run from the images directory so Go can find the module (go.mod).
# sudo is required because cmd/build uses 'podman mount' which needs root.
(cd "${IMAGES_DIR}" && sudo go run ./cmd/build \
    --bootc-ref "${CONTAINER_IMAGE}" \
    --arch "${ARCH}" \
    --type "${IMAGE_TYPE}" \
    --config "${CONFIG_FILE}" \
    --output "${BUILD_DIR}")

# sudo go run produces root-owned output; reclaim ownership so the rest of the
# pipeline (and boot.sh) can access the artifacts without sudo.
sudo chown -R "$(id -u):$(id -g)" "${BUILD_DIR}"

# Discover the build output directory (single subdirectory under build/)
BUILD_OUTPUT_DIR=$(find "${BUILD_DIR}" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | head -1)

if [ -z "${BUILD_OUTPUT_DIR}" ]; then
    echo "ERROR: No build output directory found under ${BUILD_DIR}/"
    exit 1
fi

echo "Build output directory: ${BUILD_OUTPUT_DIR}"

# Try to extract the embedded kickstart from the container image. Installer
# images ship one at /usr/share/anaconda/interactive-defaults.ks with
# the payload directive. Non-installer images won't have this file, so failures
# are silently ignored.
KS_FILENAME="embedded.ks"
# shellcheck disable=SC2024
sudo podman run --rm "${CONTAINER_IMAGE}" \
    cat /usr/share/anaconda/interactive-defaults.ks \
    > "${BUILD_OUTPUT_DIR}/${KS_FILENAME}" 2>/dev/null || true

# Write info.json for boot-image.
cat > "${BUILD_OUTPUT_DIR}/info.json" <<EOF
{
  "distro": "${DISTRO_ID}",
  "arch": "${ARCH}",
  "image-type": "${IMAGE_TYPE}"
}
EOF

# When the embedded kickstart was extracted successfully, include the
# 'iso-embedded-ks' key so the images library prepends the payload directive
# to the automation kickstart before mkksiso injection.
if [ -s "${BUILD_OUTPUT_DIR}/${KS_FILENAME}" ]; then
    TMP=$(jq --arg ks "${KS_FILENAME}" '."iso-embedded-ks" = $ks' "${BUILD_OUTPUT_DIR}/info.json")
    echo "${TMP}" > "${BUILD_OUTPUT_DIR}/info.json"
fi

# Copy the build config into the output directory for boot.sh
cp "${CONFIG_FILE}" "${BUILD_OUTPUT_DIR}/config.json"

echo "Build complete: ${BUILD_OUTPUT_DIR}"
