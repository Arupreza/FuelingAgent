#!/usr/bin/env bash
# Installs Node 22 to ~/.local/node22 without touching system Node.
# Downloads the official binary release and verifies its checksum against
# nodejs.org's own SHASUMS256.txt -- never pipes a remote script into bash.
set -euo pipefail

NODE_VERSION="22.14.0"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) NODE_ARCH="x64" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

TARBALL="node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz"
URL="https://nodejs.org/dist/v${NODE_VERSION}/${TARBALL}"
DEST="$HOME/.local/node22"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "--> downloading $URL"
curl -sfL -o "$TMP/$TARBALL" "$URL"

echo "--> verifying checksum against nodejs.org's SHASUMS256.txt"
EXPECTED="$(curl -s "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" | grep "$TARBALL" | awk '{print $1}')"
ACTUAL="$(sha256sum "$TMP/$TARBALL" | awk '{print $1}')"
if [ "$EXPECTED" != "$ACTUAL" ]; then
    echo "CHECKSUM MISMATCH -- expected $EXPECTED, got $ACTUAL. Aborting."
    exit 1
fi
echo "    checksum OK"

mkdir -p "$DEST"
tar xJf "$TMP/$TARBALL" -C "$DEST" --strip-components=1
"$DEST/bin/node" --version
echo "--> Node 22 installed at $DEST (add $DEST/bin to PATH to use it by default)"
