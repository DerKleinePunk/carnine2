#!/usr/bin/env bash
set -euo pipefail

# Packages a natively built Valhalla for the Pi as carnine-valhalla.deb.
#
#   package-deb.sh <source> <output-deb>
#
# <source> is a directory holding valhalla_service and libprime_server.so.0*,
# or user@host of a Pi with Valhalla installed under /opt/valhalla, from which
# those two are copied. Valhalla itself is built on a Pi (the build takes
# hours and is not part of build_pi.sh); only the runtime is packaged here.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${1:?Usage: package-deb.sh <directory|user@host> <output-deb>}"
OUTPUT_DEB="${2:?Usage: package-deb.sh <directory|user@host> <output-deb>}"
PACKAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT
# mktemp creates it 0700, and it becomes the "./" entry of the package.
chmod 0755 "$PACKAGE_ROOT"

install -d "$PACKAGE_ROOT/DEBIAN" "$PACKAGE_ROOT/opt/valhalla/bin" "$PACKAGE_ROOT/opt/valhalla/lib" \
  "$PACKAGE_ROOT/etc/valhalla" "$PACKAGE_ROOT/lib/systemd/system"

if [[ -d "$SOURCE" ]]; then
  cp -a "$SOURCE/valhalla_service" "$PACKAGE_ROOT/opt/valhalla/bin/"
  cp -a "$SOURCE"/libprime_server.so.0* "$PACKAGE_ROOT/opt/valhalla/lib/"
else
  rsync -a "$SOURCE:/opt/valhalla/bin/valhalla_service" "$PACKAGE_ROOT/opt/valhalla/bin/"
  rsync -a "$SOURCE:/opt/valhalla/lib/libprime_server.so.0*" "$PACKAGE_ROOT/opt/valhalla/lib/"
fi
if [[ "$(file -b "$PACKAGE_ROOT/opt/valhalla/bin/valhalla_service")" != *"ARM aarch64"* ]]; then
  echo "ERROR: valhalla_service is not an arm64 binary" >&2
  exit 1
fi

cp "$ROOT_DIR/debian/control" "$PACKAGE_ROOT/DEBIAN/control"
cp "$ROOT_DIR/debian/postinst" "$PACKAGE_ROOT/DEBIAN/postinst"
cp "$ROOT_DIR/valhalla.json" "$PACKAGE_ROOT/etc/valhalla/valhalla.json"
echo /etc/valhalla/valhalla.json > "$PACKAGE_ROOT/DEBIAN/conffiles"
cp "$ROOT_DIR/debian/valhalla.service" "$PACKAGE_ROOT/lib/systemd/system/valhalla.service"

chmod 0755 "$PACKAGE_ROOT/DEBIAN/postinst" "$PACKAGE_ROOT/opt/valhalla/bin/valhalla_service"
chmod 0644 "$PACKAGE_ROOT/etc/valhalla/valhalla.json" "$PACKAGE_ROOT/lib/systemd/system/valhalla.service" \
  "$PACKAGE_ROOT/DEBIAN/conffiles"
install -d "$(dirname "$OUTPUT_DEB")"
rm -f "$OUTPUT_DEB"
dpkg-deb --build --root-owner-group "$PACKAGE_ROOT" "$OUTPUT_DEB"
