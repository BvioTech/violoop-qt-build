#!/usr/bin/env bash
# Packages the installed $QT_PREFIX tree into a .deb. Run build.sh first.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${PKG_NAME:=violoop-qt6}"
: "${PKG_VERSION:=6.8.5-violoop1}"
: "${PKG_ARCH:=$(dpkg --print-architecture 2>/dev/null || echo arm64)}"
: "${PKG_MAINTAINER:=Violoop <alexliu@bvio.ai>}"
OUT_DIR="$ROOT_DIR/dist"

[ -d "$QT_PREFIX" ] || die "$QT_PREFIX not found, run build.sh first"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

log "staging $QT_PREFIX -> $STAGE$QT_PREFIX"
mkdir -p "$STAGE$(dirname "$QT_PREFIX")" "$STAGE/DEBIAN"
cp -a "$QT_PREFIX" "$STAGE$(dirname "$QT_PREFIX")/"

cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Architecture: $PKG_ARCH
Maintainer: $PKG_MAINTAINER
Section: libs
Priority: optional
Description: Violoop's dedicated Qt 6.8.5 build (GLES2, qtquicktimeline
 off-by-one keyframe fix) for embedded kiosk targets.
 Installed to $QT_PREFIX, does not touch Debian's system qt6-* packages.
EOF

mkdir -p "$OUT_DIR"
DEB_PATH="$OUT_DIR/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGE" "$DEB_PATH"
log "built $DEB_PATH"
