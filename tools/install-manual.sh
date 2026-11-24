#!/bin/sh
# Install the Starlink plugin by copying files into place (no package build needed).
# Run as root on the OPNsense box from inside this directory:  sh install.sh
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
[ "$(id -u)" = "0" ] || { echo "run as root"; exit 1; }
[ -x /usr/local/bin/python3 ] || { echo "python3 not found at /usr/local/bin/python3"; exit 1; }

echo ">> copying files"
cd "$HERE/../net/starlink/src"
find . -type f | while read -r f; do
    dest="/usr/local/${f#./}"
    mkdir -p "$(dirname "$dest")"
    install -m 0644 "$f" "$dest"
    echo "${dest}" >> /tmp/starlink_installed.$$
done
chmod 0755 /usr/local/opnsense/scripts/starlink/dish.py
sort -u /tmp/starlink_installed.$$ > /usr/local/opnsense/scripts/starlink/.installed_files
rm -f /tmp/starlink_installed.$$

echo ">> reloading menu/ACL caches, configd and cron"
rm -f /tmp/opnsense_menu_cache.xml /tmp/opnsense_acl_cache.json
rm -f /usr/local/opnsense/mvc/app/cache/*.php 2>/dev/null || true
service configd restart >/dev/null
/usr/local/sbin/configctl cron restart >/dev/null || true

echo ">> testing dish connection"
/usr/local/sbin/configctl starlink status | head -c 400; echo
echo
echo "Done. Open Services > Starlink in the web UI (reload the page first)."
