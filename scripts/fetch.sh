#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Fetches/updates each module's source into src/<module>/ at the ref
# pinned in modules.conf. Safe to re-run (fetch + hard reset to ref).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

fetch_one() {
    local name="$1" url="$2" ref="$3" dir="$SRC_DIR/$name"
    log "fetch $name @ $ref"
    if [ ! -d "$dir/.git" ]; then
        mkdir -p "$dir"
        git -C "$dir" init -q
        git -C "$dir" remote add origin "$url"
    fi
    git -C "$dir" fetch --depth 1 origin "refs/tags/$ref:refs/tags/$ref"
    git -C "$dir" checkout -q --detach "$ref"
}

mkdir -p "$SRC_DIR"
for_each_module fetch_one
log "all sources fetched into $SRC_DIR"
