#!/bin/bash
set -euo pipefail

CONTAINERFILE="${1:?Usage: get-container.sh <containerfile-name>}"

IMAGE_NAME="quay.io/redhat-services-prod/insights-management-tenant/image-builder-bootc-foundry/${CONTAINERFILE}:latest"

echo "Building container image: ${IMAGE_NAME}" >&2
echo "Containerfile: ${CONTAINERFILE}" >&2

sudo podman build -t "${IMAGE_NAME}" -f "${CONTAINERFILE}" . >&2

echo "Container image built: ${IMAGE_NAME}" >&2

# Print the container ref for downstream scripts to capture
echo "${IMAGE_NAME}"
