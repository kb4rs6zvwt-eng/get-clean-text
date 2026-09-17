#!/bin/bash
# Build and publish only the DMG matching the app's current version.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "$(git status --porcelain)" ]]; then
    printf 'Commiter et pousser les modifications avant de publier.\n' >&2
    exit 1
fi
python3 -B -m unittest discover -s Tests -p 'test_release.py'
./scripts/test.sh
./scripts/build.sh
python3 scripts/publish-release.py "$@"
