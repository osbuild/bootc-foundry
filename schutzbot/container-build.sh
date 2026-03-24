#!/bin/bash

set -euo pipefail
CONTAINER=$(podman build -f distribution/Dockerfile-ubi . | tail -n 1)
# podman run -e PYTHONUNBUFFERED=1 -e RH_CREDS="${RH_CREDS:-}" "$CONTAINER" --repo placeholder.org --distro "$1"
podman run "$CONTAINER"
