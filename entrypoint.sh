#!/bin/bash
set -e

cd "$(dirname "$0")"

trap "e=\$?; subscription-manager unregister || true; exit \$e" EXIT

subscription-manager register --org "$RHSM_ORG" --activationkey "$RHSM_ACTIVATIONKEY" || true

echo "$RHSM_PASSWORD" | buildah login -u "$RHSM_USERNAME" --password-stdin registry.redhat.io

if [ -n "${1:-}" ]; then
  echo "Running custom script $1 with arguments: ${*:2}"
  ./"$1" "${@:2}"
else
  echo "Running default build matrix"
  ./matrix-rhel9.sh rhel-bootc:9
  ./matrix-rhel10.sh rhel-bootc:10
fi
