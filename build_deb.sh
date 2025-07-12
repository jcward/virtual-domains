#!/bin/bash
set -e

if [[ -z "$1" ]]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION="$1"
PKG_NAME="virtual-domains"
PKG_DIR="build/${PKG_NAME}_${VERSION}"

echo "🔧 Building $PKG_NAME version $VERSION at $(date)" | tee -a .build.history

# Clean and prepare structure
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/local/bin"
mkdir -p "$PKG_DIR/usr/local/lib/virtual-domains"

# Inject version into script
sed "s/0.0.0-DEV/$VERSION/" virtual-domains > "$PKG_DIR/usr/local/bin/virtual-domains"
chmod 755 "$PKG_DIR/usr/local/bin/virtual-domains"

# Copy plugins
cp dns-plugins/*.sh "$PKG_DIR/usr/local/lib/virtual-domains/"

# Inject version into control
sed "s/0.0.0-DEV/$VERSION/" debian/control > "$PKG_DIR/DEBIAN/control"

# Copy prerm
cp debian/prerm "$PKG_DIR/DEBIAN/prerm"
chmod 755 "$PKG_DIR/DEBIAN/prerm"

# Build .deb
dpkg-deb --build "$PKG_DIR"
echo "✅ Package built: $PKG_DIR.deb"
