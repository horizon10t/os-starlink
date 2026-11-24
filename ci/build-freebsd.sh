#!/bin/sh
# Runs inside a FreeBSD VM (GitHub Actions). Builds os-starlink-*.pkg with the
# official OPNsense plugins build system and turns it into a pkg repository.
#
# env: REPO_SIGNING_KEY_B64 (optional) base64 of the RSA private key used to sign the repo
#      PLUGIN_HASH (optional) commit hash recorded in the plugin version file
set -eu

SRC=$(pwd)
OUT="$SRC/dist"
PLUGINS=/tmp/opnsense-plugins

echo ">>> installing build tools"
env ASSUME_ALWAYS_YES=yes pkg bootstrap -f >/dev/null 2>&1 || true
pkg install -y git >/dev/null

echo ">>> fetching opnsense/plugins build system"
rm -rf "$PLUGINS"
git clone --depth 1 https://github.com/opnsense/plugins.git "$PLUGINS"
rm -rf "$PLUGINS/net/starlink"
cp -R "$SRC/net/starlink" "$PLUGINS/net/starlink"
find "$PLUGINS/net/starlink" -name __pycache__ -prune -exec rm -rf {} +
chmod 0755 "$PLUGINS/net/starlink/src/opnsense/scripts/starlink/dish.py"

echo ">>> building package"
# PHP/Python versions are only informational for this pure-script plugin
make -C "$PLUGINS/net/starlink" package \
    PLUGIN_PHP=83 PLUGIN_PYTHON=311 PLUGIN_DEVEL= \
    ${PLUGIN_HASH:+PLUGIN_HASH=$(echo "$PLUGIN_HASH" | cut -c1-9)}

rm -rf "$OUT"
mkdir -p "$OUT/repo/All"
cp "$PLUGINS"/net/starlink/work/pkg/*.pkg "$OUT/repo/All/"
ls -l "$OUT/repo/All"

echo ">>> package contents"
pkg info -F "$OUT"/repo/All/*.pkg -l | sed -n '1,60p'

echo ">>> creating repository catalogue"
if [ -n "${REPO_SIGNING_KEY_B64:-}" ]; then
    umask 077
    printf '%s' "$REPO_SIGNING_KEY_B64" | openssl base64 -d -A > /tmp/repo.key
    openssl rsa -in /tmp/repo.key -pubout -out "$OUT/repo.pub" 2>/dev/null
    pkg repo "$OUT/repo" /tmp/repo.key
    rm -f /tmp/repo.key
    echo "signed with key fingerprint $(sha256 -q "$OUT/repo.pub")"
else
    echo "WARNING: REPO_SIGNING_KEY_B64 not set, publishing an UNSIGNED repository"
    pkg repo "$OUT/repo"
fi
ls -l "$OUT/repo"
