#!/bin/sh
# Install the Starlink plugin by copying files into place (no package build needed).
# Run as root on the OPNsense box:  sh tools/install-manual.sh   (or use the one-line installer, install.sh)
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

clear_ui_caches() {
    # the web UI keeps its menu and ACL caches in /tmp and in PHP's own temp directory
    rm -f /tmp/opnsense_menu_cache.xml /tmp/opnsense_acl_cache.json \
          /var/lib/php/tmp/opnsense_menu_cache.xml /var/lib/php/tmp/opnsense_acl_cache.json
    rm -f /usr/local/opnsense/mvc/app/cache/*.php 2>/dev/null || true
}

echo ">> reloading configd and cron"
service configd restart >/dev/null
/usr/local/sbin/configctl cron restart >/dev/null || true

# Clear the caches last and restart the web server, so the menu entry shows up without any manual step.
# (Restarting the web server logs you out of the web UI once; this is safe over SSH.)
echo ">> refreshing the web UI (you will be logged out once)"
clear_ui_caches
/usr/local/sbin/configctl webgui restart >/dev/null 2>&1 || true
sleep 2
clear_ui_caches

echo ">> testing dish connection"
/usr/local/sbin/configctl starlink status | head -c 400; echo
echo
echo "Done. Log in to the web UI again, hard-reload (Ctrl+F5) and open Services > Starlink."
