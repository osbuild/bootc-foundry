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

if [ -n "${1:-}" ]; then
  echo "Running custom script $1 with arguments: ${*:2}"
  ./"$1" "${@:2}"
else
  echo "Running default build matrix"
  ./matrix-rhel9.sh rhel-bootc:9
  ./matrix-rhel10.sh rhel-bootc:10
fi
