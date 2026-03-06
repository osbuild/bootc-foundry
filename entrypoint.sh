#!/bin/bash
set -xeuo pipefail

#
# This script runs generated shell scripts (see the Makefile).
#
# It can be also called with arguments, in that case these are used instead. This is used for
# upstream build tests in GitHub Actions where each distribution is executed separately.
#

cd "$(dirname "$0")"

cleanup() {
  exit_code=$?
  subscription-manager unregister || true
  exit "$exit_code"
}
trap cleanup EXIT

if [ -n "${RHSM_ORG:-}" ] && [ -n "${RHSM_ACTIVATIONKEY:-}" ]; then
  subscription-manager register --org "$RHSM_ORG" --activationkey "$RHSM_ACTIVATIONKEY" || true
else
  echo "Using subscription from the host system"
fi

if [ -n "${RHSM_USERNAME:-}" ] && [ -n "${RHSM_PASSWORD:-}" ]; then
  echo "$RHSM_PASSWORD" | buildah login -u "$RHSM_USERNAME" --password-stdin registry.redhat.io
else
  echo "Using registry.redhat.io credentials from the host system"
fi

IMAGE="rhel-bootc"
if [ -n "${AWS_REGION:-}" ] && [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ] && [ -n "${ECR_URL:-}" ]; then
  ECR_HOSTNAME=$(echo "$ECR_URL" | sed -e 's|^https://||' -e 's|^http://||')
  echo "Logging in to $ECR_HOSTNAME"
  aws ecr get-login-password --region "$AWS_REGION" | buildah login --username AWS --password-stdin "$ECR_HOSTNAME"
  IMAGE="$ECR_HOSTNAME/$IMAGE"
fi

if [ -n "${1:-}" ]; then
  echo "Running custom script $1 with arguments: ${*:2}"
  ./"$1" "${@:2}"
else
  echo "Running default build matrix"
  ./matrix-rhel9.sh "$IMAGE:9"
  ./matrix-rhel10.sh "$IMAGE:10"
fi
