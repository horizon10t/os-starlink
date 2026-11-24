#!/bin/sh
# One-line installer for os-starlink (no package build needed).
# Run as root on OPNsense:
#   fetch -o - https://raw.githubusercontent.com/horizon10t/os-starlink/main/install.sh | sh
# Install a specific tag or branch:   ... | sh -s -- v0.9
# Remove again:                       ... | sh -s -- uninstall
set -e
REPO=horizon10t/os-starlink
REF=${1:-main}
[ "$(id -u)" = "0" ] || { echo "run as root"; exit 1; }

TMP=$(mktemp -d /tmp/os-starlink.XXXXXX)
trap 'rm -rf "$TMP"' EXIT

echo ">> downloading ${REPO} (${REF})"
case "$REF" in
    uninstall) URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz" ;;
    v[0-9]*)   URL="https://github.com/${REPO}/archive/refs/tags/${REF}.tar.gz" ;;
    *)         URL="https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz" ;;
esac
fetch -q -o "$TMP/src.tar.gz" "$URL"
tar -xzf "$TMP/src.tar.gz" -C "$TMP"
DIR=$(ls -d "$TMP"/os-starlink-*/ | head -n 1)

if [ "$REF" = "uninstall" ]; then
    sh "${DIR}tools/uninstall-manual.sh"
else
    sh "${DIR}tools/install-manual.sh"
fi
