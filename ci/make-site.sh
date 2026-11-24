#!/bin/sh
# Turns dist/ (from build-freebsd.sh) into the GitHub Pages site: the pkg repo
# plus starlink.conf, the key fingerprint, setup.sh and an index page.
#
# env: SITE_URL           e.g. https://horizon10t.github.io/os-starlink
#      GITHUB_REPOSITORY  e.g. horizon10t/os-starlink (set by GitHub Actions)
set -eu
SITE_URL=${SITE_URL%/}
REPO_SLUG=${GITHUB_REPOSITORY:-horizon10t/os-starlink}
OUT=site
rm -rf "$OUT"
mkdir -p "$OUT"
cp -R dist/repo "$OUT/repo"

PKGFILE=$(cd "$OUT/repo/All" && ls os-starlink-*.pkg | head -n 1)
VERSION=$(echo "$PKGFILE" | sed -e 's/^os-starlink-//' -e 's/\.pkg$//')

FINGERPRINT=""
if [ -f dist/repo.pub ]; then
    cp dist/repo.pub "$OUT/repo.pub"
    FINGERPRINT=$(sha256sum dist/repo.pub | cut -d' ' -f1)
    printf 'function: "sha256"\nfingerprint: "%s"\n' "$FINGERPRINT" > "$OUT/repo.fingerprint"
fi

# --- pkg repository configuration -------------------------------------------
{
    echo 'starlink: {'
    echo "    url: \"${SITE_URL}/repo\","
    if [ -n "$FINGERPRINT" ]; then
        echo '    signature_type: "fingerprints",'
        echo '    fingerprints: "/usr/local/etc/pkg/fingerprints/starlink",'
    else
        echo '    signature_type: "none",'
    fi
    echo '    enabled: yes,'
    echo '    priority: 5'
    echo '}'
} > "$OUT/starlink.conf"

# --- setup.sh, run by users on OPNsense --------------------------------------
sed -e "s#@SITE_URL@#${SITE_URL}#g" -e "s#@FINGERPRINT@#${FINGERPRINT}#g" > "$OUT/setup.sh" <<'TEMPLATE'
#!/bin/sh
# Adds the os-starlink package repository to OPNsense.
# Usage (as root on OPNsense):
#   fetch -o - @SITE_URL@/setup.sh | sh             add the repository
#   fetch -o - @SITE_URL@/setup.sh | sh -s install  add it and install the plugin
set -e
[ "$(id -u)" = "0" ] || { echo "run as root"; exit 1; }
FP="@FINGERPRINT@"
mkdir -p /usr/local/etc/pkg/repos
if [ -n "$FP" ]; then
    mkdir -p /usr/local/etc/pkg/fingerprints/starlink/trusted /usr/local/etc/pkg/fingerprints/starlink/revoked
    printf 'function: "sha256"\nfingerprint: "%s"\n' "$FP" \
        > /usr/local/etc/pkg/fingerprints/starlink/trusted/repo.fingerprint
fi
fetch -q -o /usr/local/etc/pkg/repos/starlink.conf @SITE_URL@/starlink.conf
echo ">>> repository added: /usr/local/etc/pkg/repos/starlink.conf"
pkg update -f -r starlink
if [ "${1:-}" = "install" ]; then
    pkg install -y -r starlink os-starlink
    echo ">>> installed. Reload the web UI and open Services > Starlink."
else
    echo ">>> now open System > Firmware > Plugins, click 'Check for updates' and install os-starlink."
fi
TEMPLATE
chmod 0755 "$OUT/setup.sh"

# --- index page ----------------------------------------------------------------
if [ -n "$FINGERPRINT" ]; then
    SIGNED_HTML="<p>Repository signing key fingerprint (sha256): <code>${FINGERPRINT}</code></p>"
    MANUAL_FP=" and save <a href=\"repo.fingerprint\">repo.fingerprint</a> as <code>/usr/local/etc/pkg/fingerprints/starlink/trusted/repo.fingerprint</code> (with an empty <code>revoked</code> folder next to <code>trusted</code>)"
else
    SIGNED_HTML="<p><b>Note:</b> this repository is not signed.</p>"
    MANUAL_FP=""
fi
cat > "$OUT/index.html" <<HTML
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>os-starlink package repository</title>
<style>body{font:16px/1.5 system-ui,sans-serif;max-width:760px;margin:40px auto;padding:0 16px;color:#222}
pre{background:#f4f4f4;padding:12px;border-radius:6px;overflow-x:auto}code{font-size:14px}h1{font-size:26px}</style></head>
<body>
<h1>os-starlink &mdash; OPNsense plugin repository</h1>
<p>Starlink dish status, sleep schedule and control for OPNsense. Latest version: <b>${VERSION}</b>.
Source and documentation: <a href="https://github.com/${REPO_SLUG}">github.com/${REPO_SLUG}</a>.</p>
<h2>Install</h2>
<p>SSH into OPNsense as root (console option 8 for a shell) and run:</p>
<pre><code>fetch -o - ${SITE_URL}/setup.sh | sh</code></pre>
<p>Then go to <b>System &rarr; Firmware &rarr; Plugins</b>, click <b>Check for updates</b> and install <b>os-starlink</b>.
Updates then arrive through the normal firmware update screen.</p>
<h2>Manual setup</h2>
<p>Download <a href="starlink.conf">starlink.conf</a> to <code>/usr/local/etc/pkg/repos/</code>${MANUAL_FP}.</p>
${SIGNED_HTML}
<h2>Remove</h2>
<p>Remove the plugin under System &rarr; Firmware &rarr; Plugins, then:</p>
<pre><code>rm /usr/local/etc/pkg/repos/starlink.conf
rm -r /usr/local/etc/pkg/fingerprints/starlink</code></pre>
<p>Unofficial project, not affiliated with SpaceX, Starlink or Deciso.</p>
</body></html>
HTML
touch "$OUT/.nojekyll"
echo ">>> site ready for ${SITE_URL} (os-starlink ${VERSION})"
find "$OUT" -type f | sort
