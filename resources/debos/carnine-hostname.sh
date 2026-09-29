#!/bin/sh
# Gives the device a name of its own on first boot (#62): the image's
# hostname plus the last four hex digits of the Pi's serial number, e.g.
# carnine-pc-1a2b. Every image used to be called carnine-pc, and two of them
# in one network clashed over mDNS and DHCP. Runs once; a name set by hand
# since the image was built is kept.
#
# The paths can be overridden so the tests can run it on a scratch tree.

set -eu

ETC_DIR=${CARNINE_ETC_DIR:-/etc}
STATE_DIR=${CARNINE_STATE_DIR:-/var/lib/carnine}
SERIAL_FILE=${CARNINE_SERIAL_FILE:-/sys/firmware/devicetree/base/serial-number}
CPUINFO=${CARNINE_CPUINFO:-/proc/cpuinfo}
SET_HOSTNAME=${CARNINE_SET_HOSTNAME:-hostname}
MARKER="$STATE_DIR/hostname-set"

finish() {
    mkdir -p "$STATE_DIR"
    : > "$MARKER"
}

[ -e "$MARKER" ] && exit 0

base=$(cat "$ETC_DIR/carnine/image-hostname" 2>/dev/null || true)
current=$(cat "$ETC_DIR/hostname" 2>/dev/null || true)
if [ -z "$base" ] || [ "$current" != "$base" ]; then
    echo "hostname $current was set by hand or has no image name, keeping it"
    finish
    exit 0
fi

serial=""
if [ -r "$SERIAL_FILE" ]; then
    serial=$(tr -d '\000' < "$SERIAL_FILE")
fi
if [ -z "$serial" ] && [ -r "$CPUINFO" ]; then
    serial=$(awk -F': *' '/^Serial/ { print $2 }' "$CPUINFO")
fi
suffix=$(printf '%s' "$serial" | tr -cd '0-9A-Fa-f' | tr 'A-F' 'a-f' | tail -c 4)
if [ ${#suffix} -lt 4 ]; then
    echo "no serial number found, keeping hostname $current"
    finish
    exit 0
fi

name="$base-$suffix"
printf '%s\n' "$name" > "$ETC_DIR/hostname"
if grep -q "^127\.0\.1\.1[[:space:]]" "$ETC_DIR/hosts" 2>/dev/null; then
    sed -i "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$name/" "$ETC_DIR/hosts"
else
    printf '127.0.1.1\t%s\n' "$name" >> "$ETC_DIR/hosts"
fi
"$SET_HOSTNAME" "$name"
echo "hostname set to $name"
finish
