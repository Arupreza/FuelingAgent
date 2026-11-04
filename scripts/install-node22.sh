#!/usr/bin/env bash
# Installs Node 22 to ~/.local/node22 without touching system Node.
# Downloads the official binary release and verifies it against a checksum
# pinned in this file -- never pipes a remote script into bash.
set -euo pipefail

NODE_VERSION="22.14.0"

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
    linux-x64)    NODE_SHA256="69b09dba5c8dcb05c4e4273a4340db1005abeafe3927efda2bc5b249e80437ec" ;;
    linux-arm64)  NODE_SHA256="08bfbf538bad0e8cbb0269f0173cca28d705874a67a22f60b57d99dc99e30050" ;;
    darwin-x64)   NODE_SHA256="deb5b211c25f3f803cd49c1c3fc3964e6c3725546d7d9608d994270388dcbf02" ;;
    darwin-arm64) NODE_SHA256="4e845cb71b4e897289312743b2e31c405a8a48720655404d82a4dce23fc43527" ;;
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
