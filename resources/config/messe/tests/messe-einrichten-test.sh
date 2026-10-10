#!/bin/sh
# Tests messe-einrichten.sh with ssh and scp replaced by recorders: what it
# would copy and run on the device, nothing touches one.
#
#   sh resources/config/messe/tests/messe-einrichten-test.sh
set -eu

script="$(cd "$(dirname "$0")/.." && pwd)/messe-einrichten.sh"
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

# ssh records its command and stdin; "systemctl is-active" answers from
# $NETWORKD (0 = networkd runs). scp records its arguments.
mkdir "$work/bin"
cat > "$work/bin/ssh" <<'EOF'
#!/bin/sh
while [ "$#" -gt 1 ]; do shift; done
echo "SSH $1" >> "$LOG"
case "$1" in
  *"is-active --quiet systemd-networkd"*) exit "$NETWORKD" ;;
  *"tee "*) sed 's/^/STDIN /' >> "$LOG" ;;
esac
EOF
cat > "$work/bin/scp" <<'EOF'
#!/bin/sh
echo "SCP $*" >> "$LOG"
EOF
chmod +x "$work/bin/ssh" "$work/bin/scp"

run() {
  LOG="$work/log"
  : > "$LOG"
  PATH="$work/bin:$PATH" LOG="$LOG" NETWORKD="$1" bash "$script" pi@host "$2" ${3:+"$3"} > "$work/out" 2>&1
}

run 0 an 192.168.77.2
log="$work/log"
check "an: tour and drop-in are copied" "grep -q '^SCP .*messe-tour.nmea .*90-messe.toml pi@host:/tmp/' '$log'"
check "an: drop-in goes to config.d" "grep -q 'install -m 0640 -o root -g carnine /tmp/90-messe.toml /etc/carnine/config.d/90-messe.toml' '$log'"
check "an: tour goes to the maps folder" "grep -q '/var/lib/carnine/maps/messe-tour.nmea' '$log'"
check "an: fixed address written for networkd" "grep -q '^STDIN Address=192.168.77.2/24\$' '$log'"
check "an: networkd reloaded" "grep -q 'networkctl reload' '$log'"
check "an: backend and frontend restarted last" "tail -n 1 '$log' | grep -q 'restart carnine-backend && sudo systemctl restart carnine-frontend'"

run 1 an 192.168.77.3
check "an on NetworkManager: no networkd file" "! grep -q 'STDIN Address' '$log'"
check "an on NetworkManager: says how" "grep -q 'nmcli con modify .* +ipv4.addresses 192.168.77.3/24' '$work/out'"
check "an on NetworkManager: still switched on" "grep -q 'restart carnine-backend' '$log'"

run 0 an
check "an without address: network left alone" "! grep -q -e 'is-active' -e 'networkctl' '$log'"

if run 0 an 10.0.0.5; then status=0; else status=1; fi
check "an refuses an address outside 192.168.77.x" "[ $status -eq 1 ] && [ ! -s '$log' ]"

run 0 aus
check "aus: removes only the drop-in" "grep -q 'rm -f /etc/carnine/config.d/90-messe.toml' '$log' && ! grep -q 'messe-tour' '$log'"
check "aus: restarts" "grep -q 'restart carnine-backend' '$log'"

if run 0 weg; then status=0; else status=1; fi
check "an unknown action stops" "[ $status -eq 1 ]"

if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
