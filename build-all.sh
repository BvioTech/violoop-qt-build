#!/usr/bin/env bash
# Runs the full pipeline: fetch sources, build+install, package .deb.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
./scripts/fetch.sh
./scripts/build.sh
./scripts/package-deb.sh
