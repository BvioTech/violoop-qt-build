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

# Computes the real runtime Depends: via dpkg-shlibdeps, so the package
# actually declares what it needs (libicuXX/libssl3/... for the Debian
# release it was built against) instead of installing "successfully" and
# only failing to load libraries at runtime. dpkg-shlibdeps insists on a
# source-style debian/control + hard-fails on any of our own libs linking
# each other unless told they're self-provided (debian/shlibs.local) —
# both are scratch files, cleaned up before the real .deb is built.
compute_depends() {
    if ! command -v dpkg-shlibdeps >/dev/null 2>&1 || ! command -v objdump >/dev/null 2>&1; then
        log "dpkg-shlibdeps/objdump not found, Depends: will be empty"
        return
    fi

    local rel_prefix="${QT_PREFIX#/}"
    mkdir -p "$STAGE/debian"
    cat > "$STAGE/debian/control" <<EOF
Source: $PKG_NAME
Section: libs
Priority: optional
Maintainer: $PKG_MAINTAINER

Package: $PKG_NAME
Architecture: $PKG_ARCH
Depends: \${shlibs:Depends}
Description: scratch control, only used to drive dpkg-shlibdeps
EOF

    local f soname
    : > "$STAGE/debian/shlibs.local"
    while IFS= read -r -d '' f; do
        soname="$(objdump -p "$f" 2>/dev/null | awk '/SONAME/{print $2; exit}')"
        [ -z "$soname" ] && continue
        printf '%s %s \n' "${soname%.so.*}" "${soname##*.so.}" >> "$STAGE/debian/shlibs.local"
    done < <(find "$STAGE$QT_PREFIX/lib" -maxdepth 1 -type f -name '*.so*' -print0 2>/dev/null)
    sort -u -o "$STAGE/debian/shlibs.local" "$STAGE/debian/shlibs.local"

    local elf_files=() rel
    while IFS= read -r -d '' f; do
        elf_files+=("${f#"$STAGE"/}")
    done < <(find "$STAGE$QT_PREFIX" -type f \( -name '*.so*' -o -perm -u+x \) -print0)

    local shlibdeps_out="" rc=0
    if [ "${#elf_files[@]}" -gt 0 ]; then
        set +e
        shlibdeps_out="$(cd "$STAGE" && dpkg-shlibdeps -O -l"$rel_prefix/lib" "${elf_files[@]}" 2>&1)"
        rc=$?
        set -e
    fi
    rm -rf "$STAGE/debian"
    [ "$rc" -eq 0 ] || die "dpkg-shlibdeps failed:"$'\n'"$shlibdeps_out"
    printf '%s\n' "$shlibdeps_out" | sed -n 's/^shlibs:Depends=//p'
}

PKG_DEPENDS="$(compute_depends)"
log "Depends: ${PKG_DEPENDS:-<none detected>}"

# Built line-by-line, not via a heredoc with an inline conditional: an
# empty $(...) substitution still leaves a blank line behind, and a
# blank line inside DEBIAN/control is a stanza separator to dpkg — that
# silently splits the file into two invalid "packages".
{
    echo "Package: $PKG_NAME"
    echo "Version: $PKG_VERSION"
    echo "Architecture: $PKG_ARCH"
    echo "Maintainer: $PKG_MAINTAINER"
    echo "Homepage: $PKG_HOMEPAGE"
    echo "Section: libs"
    echo "Priority: optional"
    [ -n "$PKG_DEPENDS" ] && echo "Depends: $PKG_DEPENDS"
    echo "Description: Violoop's dedicated Qt 6.8.5 build (GLES2, qtquicktimeline"
    echo " off-by-one keyframe fix) for embedded kiosk targets."
    echo " Installed to $QT_PREFIX, does not touch Debian's system qt6-* packages."
} > "$STAGE/DEBIAN/control"

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
