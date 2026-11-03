#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Packages the installed $QT_PREFIX tree into a .deb. Run build.sh first.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

: "${PKG_NAME:=violoop-qt6}"
: "${PKG_VERSION:=6.8.5-violoop1}"
: "${PKG_ARCH:=$(dpkg --print-architecture 2>/dev/null || echo arm64)}"
: "${PKG_MAINTAINER:=Violoop <doctor@bvio.ai>}"
: "${PKG_HOMEPAGE:=https://github.com/BvioTech/violoop-qt-build}"
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
Homepage: $PKG_HOMEPAGE
Section: libs
Priority: optional
Description: Violoop's dedicated Qt 6.8.5 build (GLES2, qtquicktimeline
 off-by-one keyframe fix) for embedded kiosk targets.
 Installed to $QT_PREFIX, does not touch Debian's system qt6-* packages.
EOF

# Debian-style copyright file: this package's *contents* are Qt itself
# (each module under its own upstream license, mostly LGPL-3.0-only, with
# per-file detail in each module's own LICENSES/+REUSE.toml at the exact
# ref below — that in-tree data is authoritative, this is a pointer to
# it, not a substitute for it). The *packaging* (these build scripts) is
# a separate, our-own GPL-3.0-or-later work, listed separately below.
DOC_DIR="$STAGE/usr/share/doc/$PKG_NAME"
mkdir -p "$DOC_DIR"
{
    echo "Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/"
    echo "Upstream-Name: Qt"
    echo "Source: $PKG_HOMEPAGE"
    echo
    echo "Files: *"
    echo "Copyright: The Qt Company Ltd. and contributors"
    echo "License: LGPL-3.0-only"
    echo " Qt is multi-licensed on a per-file basis. The modules bundled in"
    echo " this package are predominantly LGPL-3.0-only, with a long tail of"
    echo " third-party components under their own licenses (Apache-2.0, MIT,"
    echo " BSD, GPL-3.0-only with the Qt-GPL-exception, etc). This is a"
    echo " packaging-level summary, not a legal determination for any"
    echo " specific file — the authoritative, file-level license data ships"
    echo " inside each module's own source tree (LICENSES/, REUSE.toml,"
    echo " licenseRule.json) at the exact ref listed below."
    echo
    while read -r name url ref; do
        [ -z "$name" ] && continue
        case "$name" in \#*) continue ;; esac
        echo "Module: $name"
        echo "Source: $url"
        echo "Ref: $ref"
        echo
    done < "$MODULES_FILE"
    echo "Comment:"
    echo " None of the above is this package's own work — it is Qt itself,"
    echo " fetched and built per the module table above. The build/packaging"
    echo " tooling that produced this .deb (not shipped inside it) is a"
    echo " separate, our-own work, licensed GPL-3.0-or-later: see"
    echo " $PKG_HOMEPAGE/blob/main/LICENSE."
} > "$DOC_DIR/copyright"

mkdir -p "$OUT_DIR"
DEB_PATH="$OUT_DIR/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGE" "$DEB_PATH"
log "built $DEB_PATH"
