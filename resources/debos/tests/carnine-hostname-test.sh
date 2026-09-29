#!/bin/sh
# Tests for carnine-hostname.sh (#62) on a scratch tree; no root needed.

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/carnine-hostname.sh"
failures=0

# A fresh image: /etc/hostname and /etc/carnine/image-hostname both hold $1.
setup() {
    tree=$(mktemp -d)
    mkdir -p "$tree/etc/carnine" "$tree/state"
    printf '%s\n' "$1" > "$tree/etc/hostname"
    printf '%s\n' "$1" > "$tree/etc/carnine/image-hostname"
    printf '127.0.0.1\tlocalhost\n127.0.1.1\t%s\n' "$1" > "$tree/etc/hosts"
    : > "$tree/set-hostname.log"
}

run() {
    CARNINE_ETC_DIR="$tree/etc" CARNINE_STATE_DIR="$tree/state" \
        CARNINE_SERIAL_FILE="$tree/serial" CARNINE_CPUINFO="$tree/cpuinfo" \
        CARNINE_SET_HOSTNAME="$tree/fake-hostname" \
        sh "$SCRIPT" > /dev/null
}

fake_hostname() {
    # $1 belongs to the generated script, not to this one.
    # shellcheck disable=SC2016
    printf '#!/bin/sh\necho "$1" >> "%s/set-hostname.log"\n' "$tree" > "$tree/fake-hostname"
    chmod +x "$tree/fake-hostname"
}

check() {
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: expected '$3', got '$2'"
        failures=$((failures + 1))
    else
        echo "ok: $1"
    fi
}

# Serial from the device tree, with the trailing NUL it has there.
setup carnine-pc; fake_hostname
printf '10000000a1b2C3d4\000' > "$tree/serial"
run
check "name from the device tree serial" "$(cat "$tree/etc/hostname")" "carnine-pc-c3d4"
check "hosts line follows" "$(grep '^127.0.1.1' "$tree/etc/hosts")" "$(printf '127.0.1.1\tcarnine-pc-c3d4')"
check "running hostname is set" "$(cat "$tree/set-hostname.log")" "carnine-pc-c3d4"
check "localhost line stays" "$(grep -c '^127.0.0.1' "$tree/etc/hosts")" "1"

# Runs only once: a second run changes nothing even with another serial.
printf '10000000ffffeeee\000' > "$tree/serial"
run
check "second run keeps the name" "$(cat "$tree/etc/hostname")" "carnine-pc-c3d4"
rm -rf "$tree"

# No device tree serial: /proc/cpuinfo.
setup carnine-pc; fake_hostname
printf 'Hardware\t: BCM2835\nSerial\t\t: 00000000DEADBEEF\nModel\t\t: Raspberry Pi 3\n' > "$tree/cpuinfo"
run
check "name from /proc/cpuinfo" "$(cat "$tree/etc/hostname")" "carnine-pc-beef"
rm -rf "$tree"

# A name set by hand since the image was built is kept.
setup carnine-pc; fake_hostname
printf 'messe-auto-2\n' > "$tree/etc/hostname"
printf '10000000a1b2c3d4\000' > "$tree/serial"
run
check "hand-set name kept" "$(cat "$tree/etc/hostname")" "messe-auto-2"
check "hand-set name: nothing set" "$(cat "$tree/set-hostname.log")" ""
check "hand-set name: marker written" "$(test -e "$tree/state/hostname-set" && echo yes)" "yes"
rm -rf "$tree"

# Without any serial number the name stays.
setup carnine-pc; fake_hostname
run
check "no serial keeps the name" "$(cat "$tree/etc/hostname")" "carnine-pc"
rm -rf "$tree"

if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "all carnine-hostname tests passed"
