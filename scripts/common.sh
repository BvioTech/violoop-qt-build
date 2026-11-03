#!/usr/bin/env bash
# Shared config/helpers for the build scripts. Source this, don't run it.

: "${QT_PREFIX:=/opt/violoop-qt6}"
: "${QT_JOBS:=$(nproc)}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_FILE="$ROOT_DIR/modules.conf"
SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Reads modules.conf, skipping blanks/comments. Calls "$1" with
# name, url, ref for each module in file order (= build order).
for_each_module() {
    local cb="$1" name url ref
    [ -f "$MODULES_FILE" ] || die "modules.conf not found at $MODULES_FILE"
    while read -r name url ref; do
        [ -z "$name" ] && continue
        case "$name" in \#*) continue ;; esac
        "$cb" "$name" "$url" "$ref"
    done < "$MODULES_FILE"
}
