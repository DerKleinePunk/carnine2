#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE="Usage: package-deb.sh <ivi-homescreen-bundle> <output-deb> <version> <ivi-homescreen-licenses>"
BUNDLE_DIR="${1:?$USAGE}"
OUTPUT_DEB="${2:?$USAGE}"
VERSION="${3:?$USAGE}"
# From gen_sbom.py --licenses-output (#123).
IHS_LICENSES="${4:?$USAGE}"
PACKAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT

install -d "$PACKAGE_ROOT/DEBIAN" "$PACKAGE_ROOT/opt/carnine/frontend" "$PACKAGE_ROOT/usr/bin" "$PACKAGE_ROOT/lib/systemd/system" \
  "$PACKAGE_ROOT/usr/share/doc/carnine-frontend"
cp "$ROOT_DIR/debian/control" "$PACKAGE_ROOT/DEBIAN/control"
sed -i "s/^Version: .*/Version: $VERSION/" "$PACKAGE_ROOT/DEBIAN/control"
cp "$ROOT_DIR/debian/postinst" "$PACKAGE_ROOT/DEBIAN/postinst"
cp "$ROOT_DIR/debian/carnine-frontend" "$PACKAGE_ROOT/usr/bin/carnine-frontend"
cp "$ROOT_DIR/debian/carnine-frontend.service" "$PACKAGE_ROOT/lib/systemd/system/carnine-frontend.service"
cp -a "$BUNDLE_DIR/." "$PACKAGE_ROOT/opt/carnine/frontend/"
cp "$ROOT_DIR/debian/copyright" "$PACKAGE_ROOT/usr/share/doc/carnine-frontend/copyright"
cp "$IHS_LICENSES" "$PACKAGE_ROOT/usr/share/doc/carnine-frontend/ivi-homescreen-licenses.txt"

chmod 0755 "$PACKAGE_ROOT/DEBIAN/postinst" "$PACKAGE_ROOT/usr/bin/carnine-frontend"
chmod 0644 "$PACKAGE_ROOT/lib/systemd/system/carnine-frontend.service" \
  "$PACKAGE_ROOT/usr/share/doc/carnine-frontend/copyright" \
  "$PACKAGE_ROOT/usr/share/doc/carnine-frontend/ivi-homescreen-licenses.txt"
install -d "$(dirname "$OUTPUT_DEB")"
rm -f "$OUTPUT_DEB"
dpkg-deb --build --root-owner-group "$PACKAGE_ROOT" "$OUTPUT_DEB"