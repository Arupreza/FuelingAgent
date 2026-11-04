#!/usr/bin/env bash
# Installs Node 22 to ~/.local/node22 without touching system Node.
# Downloads the official binary release and verifies it against a checksum
# pinned in this file -- never pipes a remote script into bash.
set -euo pipefail

# Bumped from 22.14.0: the skills CLI now requires node >=22.20.0, so the
# pinned Node could not run the pinned skills package. Pinning one side and
# not the other is how that went unnoticed.
NODE_VERSION="22.23.4"

# The OS was hardcoded to linux, so on macOS this fetched a Linux tarball:
# the checksum passed, tar extracted, and the failure only surfaced as an
# exec-format error from `node --version`.
case "$(uname -s)" in
    Linux)  NODE_OS="linux" ;;
    Darwin) NODE_OS="darwin" ;;
    *) echo "Unsupported OS: $(uname -s)"; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64) NODE_ARCH="x64" ;;
    aarch64|arm64) NODE_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;;
esac

# Hashes pinned here rather than read from nodejs.org. Fetching SHASUMS256.txt
# over the same connection as the tarball detects a corrupted download but not
# a compromised origin: whoever can serve one can serve the other. The version
# is already pinned, so the hash can be too, and a change then has to be a
# commit to this repository.
case "${NODE_OS}-${NODE_ARCH}" in
    linux-x64)    NODE_SHA256="1805bcd35e6815559bd2eb97db438d3fdb0eb3a5e6a977b7c1badca76337e9ce" ;;
    linux-arm64)  NODE_SHA256="6287aa46b6c375d816e63ae66d024fbbfd70404825aabdfdf898a970871d2f4b" ;;
    darwin-x64)   NODE_SHA256="f42abca7aaac61efc57d49fb42ea84fc53bbeba9a749cb03a291ce6e4e7a69c1" ;;
    darwin-arm64) NODE_SHA256="037650d0839f457747396f052073fb48333d31bf5abd3c98b74da20d89ebb1ad" ;;
    *) echo "No pinned checksum for ${NODE_OS}-${NODE_ARCH}"; exit 1 ;;
esac

TARBALL="node-v${NODE_VERSION}-${NODE_OS}-${NODE_ARCH}.tar.xz"
URL="https://nodejs.org/dist/v${NODE_VERSION}/${TARBALL}"
DEST="$HOME/.local/node22"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "--> downloading $URL"
curl -sfL -o "$TMP/$TARBALL" "$URL"

echo "--> verifying against the checksum pinned in this script"
if command -v sha256sum >/dev/null 2>&1; then
    ACTUAL="$(sha256sum "$TMP/$TARBALL" | awk '{print $1}')"
else
    ACTUAL="$(shasum -a 256 "$TMP/$TARBALL" | awk '{print $1}')"   # macOS
fi
if [ "$NODE_SHA256" != "$ACTUAL" ]; then
    echo "CHECKSUM MISMATCH -- expected $NODE_SHA256, got $ACTUAL. Aborting."
    exit 1
fi
echo "    checksum OK"

mkdir -p "$DEST"
tar xJf "$TMP/$TARBALL" -C "$DEST" --strip-components=1
"$DEST/bin/node" --version
echo "--> Node 22 installed at $DEST (add $DEST/bin to PATH to use it by default)"
