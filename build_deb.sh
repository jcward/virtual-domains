#!/bin/bash
set -e

VERSION="0.1.0"
PKG_NAME="virtual-domains"
PKG_DIR="build/${PKG_NAME}_${VERSION}"

echo "🔧 Building $PKG_NAME version $VERSION"

# Clean previous
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/local/bin"
mkdir -p "$PKG_DIR/usr/local/lib/virtual-domains"

# Copy main script and plugins
cp virtual-domains.sh "$PKG_DIR/usr/local/bin/"
cp dns-plugins/*.sh "$PKG_DIR/usr/local/lib/virtual-domains/"

# Copy control files
cp debian/control "$PKG_DIR/DEBIAN/control"
cp debian/prerm "$PKG_DIR/DEBIAN/prerm"

# Build package
dpkg-deb --build "$PKG_DIR"

echo "✅ Package built: $PKG_DIR.deb"
