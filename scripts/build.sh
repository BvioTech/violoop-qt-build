#!/usr/bin/env bash
# Builds+installs every module in modules.conf, in file order, into
# $QT_PREFIX. Must run fetch.sh first. Re-run is incremental (ninja/cmake
# caches are kept under build/<module>/).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

build_qtbase() {
    local src="$SRC_DIR/qtbase" build="$BUILD_DIR/qtbase"
    mkdir -p "$build"
    cd "$build"
    # -opengl es2 is the whole fix: left to auto-detect, configure picks
    # desktop OpenGL/GLVND on any build machine with Mesa dev packages
    # installed, which silently breaks GL context accounting on target
    # (Mali) hardware. See docs/README.md for the full story. Do not
    # remove this flag or let it fall back to auto-detection.
    "$src/configure" \
        -prefix "$QT_PREFIX" -release -opengl es2 -no-feature-xcb \
        -nomake examples -nomake tests
    cmake --build . --parallel "$QT_JOBS"
    cmake --install .
}

build_module() {
    local name="$1" src="$SRC_DIR/$name" build="$BUILD_DIR/$name"
    mkdir -p "$build"
    cd "$build"
    "$QT_PREFIX/bin/qt-configure-module" "$src" \
        -- -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF
    cmake --build . --parallel "$QT_JOBS"
    cmake --install .
}

build_one() {
    local name="$1"
    log "build $name -> $QT_PREFIX"
    if [ "$name" = "qtbase" ]; then
        build_qtbase
    else
        build_module "$name"
    fi
}

mkdir -p "$BUILD_DIR" "$QT_PREFIX"
for_each_module build_one
log "build complete, installed to $QT_PREFIX"
log "verify: grep -E 'FEATURE_opengl(_desktop|es2)' $BUILD_DIR/qtbase/CMakeCache.txt"
