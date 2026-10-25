#!/bin/sh
# Tests package-deb.sh with a stand-in bundle: the start order and the boot
# logo handover in the finished .deb.
#
#   sh src/frontend/debian/tests/package-deb-test.sh
# The checks are evaluated later, so their variables stay in single quotes.
# shellcheck disable=SC2016,SC2034
set -eu

script="$(cd "$(dirname "$0")/../.." && pwd)/package-deb.sh"
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

mkdir -p "$work/bundle/lib"
printf '#!/bin/sh\n' > "$work/bundle/homescreen"
chmod 0755 "$work/bundle/homescreen"
echo licences > "$work/licenses.txt"
bash "$script" "$work/bundle" "$work/out.deb" 1.0 "$work/licenses.txt" > /dev/null
dpkg-deb -x "$work/out.deb" "$work/root"
unit="$work/root/lib/systemd/system/carnine-frontend.service"
dropin="$work/root/lib/systemd/system/plymouth-quit.service.d/carnine-frontend.conf"

check "the unit is in the package" '[ -f "$unit" ]'
check "the frontend does not wait for the backend" \
  '! grep -E "^After=.*carnine-backend\.service" "$unit" > /dev/null'
check "the backend is still pulled in" 'grep -E "^Wants=.*carnine-backend\.service" "$unit" > /dev/null'
check "the frontend makes Plymouth let go of the display" \
  'grep -Fx "ExecStartPre=-+/usr/bin/plymouth deactivate" "$unit" > /dev/null'
check "the plymouth-quit drop-in comes along" '[ -f "$dropin" ]'
check "plymouth-quit waits for the frontend" 'grep -Fx "After=carnine-frontend.service" "$dropin" > /dev/null'
check "plymouth-quit keeps the logo up" \
  'grep -Fx "ExecStart=-/usr/bin/plymouth quit --retain-splash" "$dropin" > /dev/null'
check "the stock quit command is cleared first" \
  '[ "$(grep -c "^ExecStart=" "$dropin")" = 2 ] && [ "$(grep -m1 "^ExecStart=" "$dropin")" = "ExecStart=" ]'
check "the drop-in is world-readable" '[ "$(stat -c %a "$dropin")" = 644 ]'

if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
