#!/bin/sh
# Remove the manually installed Starlink plugin. Settings stay in config.xml.
set -e
[ "$(id -u)" = "0" ] || { echo "run as root"; exit 1; }
LIST=/usr/local/opnsense/scripts/starlink/.installed_files
if [ -f "$LIST" ]; then
    while read -r f; do rm -f "$f"; done < "$LIST"
fi
rm -rf /usr/local/opnsense/scripts/starlink /usr/local/opnsense/mvc/app/views/OPNsense/Starlink \
       /usr/local/opnsense/mvc/app/controllers/OPNsense/Starlink /usr/local/opnsense/mvc/app/models/OPNsense/Starlink \
       /var/db/starlink
rm -f /usr/local/opnsense/service/conf/actions.d/actions_starlink.conf /usr/local/etc/inc/plugins.inc.d/starlink.inc \
      /usr/local/opnsense/www/js/widgets/Starlink.js /usr/local/opnsense/www/js/widgets/Metadata/Starlink.xml
rm -f /tmp/opnsense_menu_cache.xml /tmp/opnsense_acl_cache.json
service configd restart >/dev/null
/usr/local/sbin/configctl cron restart >/dev/null || true
echo "Starlink plugin removed."
