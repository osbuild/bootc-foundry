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

BUILD_NAME="bootc_${ARCH//-/_}_${IMAGE_TYPE//-/_}_bootc_foundry"
BUILD_OUTPUT_DIR="${BUILD_DIR}/${BUILD_NAME}"

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

# Extract blueprint for --blueprint (image-builder no longer takes --config).
BLUEPRINT_FILE=$(mktemp --suffix=.json)
trap 'rm -f "${BLUEPRINT_FILE}"' EXIT # Remove the temp file on exit.
jq '.blueprint // {}' "${CONFIG_FILE}" > "${BLUEPRINT_FILE}"

mkdir -p "${BUILD_OUTPUT_DIR}"
(
    cd "${IMAGES_DIR}"
    go build -o ./bin/image-builder ./cmd/image-builder
    BUILD_ARGS=(
        ./bin/image-builder build "${IMAGE_TYPE}"
        --bootc-ref "${CONTAINER_IMAGE}"
        --arch "${ARCH}"
        --output-dir "${BUILD_OUTPUT_DIR}"
        --output-name "${BUILD_NAME}"
        --with-manifest
        --ignore-warnings
        --blueprint "${BLUEPRINT_FILE}"
    )
    if [ -n "${PAYLOAD_CONTAINER_IMAGE}" ]; then
        BUILD_ARGS+=(--bootc-installer-payload-ref "${PAYLOAD_CONTAINER_IMAGE}")
    fi
    # sudo is required because image-builder uses podman mount / osbuild as root.
    sudo "${BUILD_ARGS[@]}"
)

# sudo produces root-owned output; reclaim ownership so the rest of the
# pipeline (and boot.sh) can access the artifacts without sudo.
sudo chown -R "$(id -u):$(id -g)" "${BUILD_DIR}"

OSBUILD_MANIFEST="${BUILD_OUTPUT_DIR}/${BUILD_NAME}.osbuild-manifest.json"
MANIFEST_JSON="${BUILD_OUTPUT_DIR}/manifest.json"
if [ -f "${OSBUILD_MANIFEST}" ] && [ ! -e "${MANIFEST_JSON}" ]; then
    ln -s "${BUILD_NAME}.osbuild-manifest.json" "${MANIFEST_JSON}"
fi

if [ ! -d "${BUILD_OUTPUT_DIR}" ]; then
    echo "ERROR: No build output directory found: ${BUILD_OUTPUT_DIR}"
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
