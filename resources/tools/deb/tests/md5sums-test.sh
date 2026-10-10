#!/bin/sh
# Tests md5sums.sh with a small package: tree and finished .deb.
#
#   sh resources/tools/deb/tests/md5sums-test.sh
set -eu

script="$(cd "$(dirname "$0")/.." && pwd)/md5sums.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

check() {
  if eval "$2"; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    failures=$((failures + 1))
  fi
}

make_tree() {
  root="$1"
  mkdir -p "$root/DEBIAN" "$root/usr/bin" "$root/etc/demo" "$root/usr/share/doc/demo"
  chmod 0755 "$root"
  printf 'Package: demo\nVersion: 1.0\nArchitecture: all\nMaintainer: t <t@example.invalid>\nDescription: demo\n' \
    > "$root/DEBIAN/control"
  echo /etc/demo/demo.conf > "$root/DEBIAN/conffiles"
  printf '#!/bin/sh\n' > "$root/usr/bin/demo"
  chmod 0755 "$root/usr/bin/demo"
  echo setting > "$root/etc/demo/demo.conf"
  echo text > "$root/usr/share/doc/demo/file with space.txt"
  ln -s demo "$root/usr/bin/demo-link"
}

# A tree: every file but the conffile, with paths dpkg can check.
make_tree "$work/tree"
sh "$script" "$work/tree"
sums="$work/tree/DEBIAN/md5sums"
check "tree: md5sums lists the program" "grep -q '  usr/bin/demo\$' '$sums'"
check "tree: a name with a space" "grep -q '  usr/share/doc/demo/file with space.txt\$' '$sums'"
check "tree: the conffile is left out" "! grep -q 'demo.conf' '$sums'"
check "tree: no symlink, no DEBIAN file" "! grep -q -e 'demo-link' -e 'DEBIAN' '$sums'"
check "tree: the sums are right" "(cd '$work/tree' && md5sum --quiet -c DEBIAN/md5sums)"

# A finished .deb without md5sums gets them and stays installable.
make_tree "$work/deb"
dpkg-deb --build --root-owner-group "$work/deb" "$work/demo.deb" > /dev/null
check "deb: none before" "! dpkg-deb --ctrl-tarfile '$work/demo.deb' | tar -t | grep -q md5sums"
sh "$script" "$work/demo.deb"
check "deb: md5sums after" "dpkg-deb --ctrl-tarfile '$work/demo.deb' | tar -t | grep -q '^./md5sums\$'"
check "deb: conffiles kept" "dpkg-deb --ctrl-tarfile '$work/demo.deb' | tar -t | grep -q '^./conffiles\$'"
check "deb: owned by root" "dpkg-deb -c '$work/demo.deb' | awk '{print \$2}' | sort -u | grep -qx 'root/root'"
check "deb: the top directory is 0755" "dpkg-deb -c '$work/demo.deb' | grep -q '^drwxr-xr-x root/root .* \\./\$'"
check "deb: the program stays executable" "dpkg-deb -c '$work/demo.deb' | grep -q '^-rwxr-xr-x .* \\./usr/bin/demo\$'"

# cargo-deb writes no "./" entry; the package still gets "./" as 0755.
make_tree "$work/bare"
rm "$work/bare/DEBIAN/conffiles" "$work/bare/etc/demo/demo.conf"
(
  cd "$work/bare"
  tar -C DEBIAN --owner=0 --group=0 -czf "$work/control.tar.gz" ./control
  tar --owner=0 --group=0 -czf "$work/data.tar.gz" ./usr
  echo 2.0 > "$work/debian-binary"
)
(cd "$work" && ar rc bare.deb debian-binary control.tar.gz data.tar.gz)
check "bare deb: no ./ entry before" "! dpkg-deb -c '$work/bare.deb' | grep -q ' \./\$'"
sh "$script" "$work/bare.deb"
check "bare deb: the top directory is 0755" "dpkg-deb -c '$work/bare.deb' | grep -q '^drwxr-xr-x root/root .* \./\$'"

check "neither tree nor .deb stops" "! sh '$script' '$work/nowhere' 2> /dev/null"

if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
