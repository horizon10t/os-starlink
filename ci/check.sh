#!/bin/sh
# Static checks and unit tests (runs on the Ubuntu runner, no FreeBSD needed).
set -eu
cd "$(dirname "$0")/.."
P=net/starlink
echo ">>> PHP syntax"
find $P -name '*.php' -o -name '*.inc' | while read -r f; do php -l "$f" > /dev/null; done
echo ">>> Python syntax"
python3 -m py_compile $P/src/opnsense/scripts/starlink/*.py tools/*.py tests/*.py
echo ">>> JavaScript syntax"
node --check $P/src/opnsense/www/js/widgets/Starlink.js
echo ">>> XML well-formed"
find $P -name '*.xml' -exec python3 -c 'import sys,xml.etree.ElementTree as E;[E.parse(f) for f in sys.argv[1:]]' {} +
echo ">>> shell syntax"
for f in ci/*.sh tools/*.sh; do sh -n "$f"; done
echo ">>> dish.py must be executable"
test -x $P/src/opnsense/scripts/starlink/dish.py
echo ">>> tag matches plugin version"
VER=$(awk '/^PLUGIN_VERSION=/{print $2}' $P/Makefile)
REV=$(awk '/^PLUGIN_REVISION=/{print $2}' $P/Makefile)
[ -n "$REV" ] && [ "$REV" != "0" ] && VER="${VER}_${REV}"
case "${GITHUB_REF:-}" in
    refs/tags/v*) [ "${GITHUB_REF#refs/tags/v}" = "$VER" ] || { echo "tag ${GITHUB_REF#refs/tags/} != plugin version $VER"; exit 1; } ;;
esac
echo ">>> unit tests"
python3 tests/test_backend.py
find . -name __pycache__ -prune -exec rm -rf {} +
echo "all checks passed (plugin version $VER)"
