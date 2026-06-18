#!/bin/bash
set -euo pipefail

# This script prepares the source tree before committing changes.
# It should be run after making changes to Containerfiles or other
# files that affect the CI configuration.

cd "$(dirname "$0")/.."

echo "Regenerating .gitlab-ci.yml..."
python3 test/generate_ci.py > .gitlab-ci.yml

echo "Done! Don't forget to add .gitlab-ci.yml to your commit."
