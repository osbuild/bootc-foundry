#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGES_DIR="${REPO_ROOT}/_images"

IMAGES_REPO_URL="${IMAGES_REPO_URL:-https://github.com/osbuild/images.git}"

# Read the images library ref from Schutzfile
IMAGES_REF=$(jq -r '.common.dependencies.images.ref' "${REPO_ROOT}/Schutzfile")

echo "Images library ref: ${IMAGES_REF}"
echo "Images repo URL: ${IMAGES_REPO_URL}"

# Clone the images library at the pinned ref
rm -rf "${IMAGES_DIR}"
echo "Cloning images library at ${IMAGES_REF}"
git clone "${IMAGES_REPO_URL}" "${IMAGES_DIR}"
git -C "${IMAGES_DIR}" checkout "${IMAGES_REF}"

# Set up the osbuild RPM repository. The images library's setup-osbuild-repo
# auto-detects the host distro from /etc/os-release and reads the matching
# per-distro or common osbuild commit from its own Schutzfile.
sudo "${IMAGES_DIR}/test/scripts/setup-osbuild-repo"

# Install all dependencies using the images library's install script
sudo "${IMAGES_DIR}/test/scripts/install-dependencies"

# Ensure that the system is subscribed if needed
if [ "${SUBSCRIPTION_NEEDED:-false}" = "true" ]; then
    if [ -z "${V2_RHN_REGISTRATION_SCRIPT:-}" ]; then
        echo "ERROR: SUBSCRIPTION_NEEDED is set but V2_RHN_REGISTRATION_SCRIPT is empty"
        exit 1
    fi

    echo "Registering system with Red Hat Subscription Manager"
    sudo dnf install -y subscription-manager
    set +x
    echo "${V2_RHN_REGISTRATION_SCRIPT}" | sudo bash
fi
