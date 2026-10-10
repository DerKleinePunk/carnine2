#!/bin/sh
# Writes DEBIAN/md5sums into a Debian package, so `dpkg -V` on the device
# tells a file changed after installing (a hand-copied valhalla.service went
# unnoticed for two weeks that way, 2026-10-10).
#
#   md5sums.sh <package-root>   tree for dpkg-deb --build, before building
#   md5sums.sh <package.deb>    finished package (cargo-deb writes none):
#                               unpacked, given the file, packed again (xz)
#
# Conffiles are left out, as dh_md5sums does; dpkg keeps their hashes itself.
set -eu

usage="Usage: md5sums.sh <package-root|package.deb>"
target="${1:?$usage}"

write_md5sums() {
  root="$1"
  conffiles="$(mktemp)"
  if [ -f "$root/DEBIAN/conffiles" ]; then
    sed 's|^/||' "$root/DEBIAN/conffiles" > "$conffiles"
  fi
  (
    cd "$root"
    find . -path ./DEBIAN -prune -o -type f -print | sed 's|^\./||' | LC_ALL=C sort |
      grep -vxF -f "$conffiles" | xargs -r -d '\n' md5sum
  ) > "$root/DEBIAN/md5sums.new"
  rm -f "$conffiles"
  mv "$root/DEBIAN/md5sums.new" "$root/DEBIAN/md5sums"
  chmod 0644 "$root/DEBIAN/md5sums"
}

if [ -d "$target" ]; then
  write_md5sums "$target"
elif [ -f "$target" ]; then
  tree="$(mktemp -d)"
  trap 'rm -rf "$tree"' EXIT
  dpkg-deb -R "$target" "$tree"
  # It becomes the "./" entry of the package. mktemp made it 0700, and a
  # package without a "./" entry of its own (cargo-deb) leaves it so.
  chmod 0755 "$tree"
  write_md5sums "$tree"
  dpkg-deb --build --root-owner-group -Zxz "$tree" "$target" > /dev/null
else
  echo "md5sums.sh: no package tree or .deb: $target" >&2
  exit 1
fi
