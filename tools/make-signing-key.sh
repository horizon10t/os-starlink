#!/bin/sh
# Create the RSA key that signs the package repository.
# Run once on your own computer, NOT in the repository folder you commit.
#
#   sh tools/make-signing-key.sh ~/os-starlink-signing
#
# Then add the printed one-line value as the GitHub secret REPO_SIGNING_KEY_B64
# (repo Settings > Secrets and variables > Actions > New repository secret).
# Keep the .key file safe: if you lose it, users must re-run setup.sh after you make a new one.
set -eu
DIR=${1:-./os-starlink-signing}
mkdir -p "$DIR"
umask 077
openssl genrsa -out "$DIR/repo.key" 4096 2>/dev/null
openssl rsa -in "$DIR/repo.key" -pubout -out "$DIR/repo.pub" 2>/dev/null
if command -v sha256sum >/dev/null 2>&1; then FP=$(sha256sum "$DIR/repo.pub" | cut -d' ' -f1); else FP=$(shasum -a 256 "$DIR/repo.pub" | cut -d' ' -f1); fi
echo "Private key: $DIR/repo.key  (keep secret, back it up)"
echo "Public key:  $DIR/repo.pub"
echo "Fingerprint: $FP"
echo
echo "GitHub secret REPO_SIGNING_KEY_B64 value (one line):"
echo
openssl base64 -A -in "$DIR/repo.key"
echo
