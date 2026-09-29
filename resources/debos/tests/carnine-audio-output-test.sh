#!/bin/sh
# Tests for carnine-audio-output.sh (#64) on a scratch tree; no root needed.

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/carnine-audio-output.sh"
failures=0

check() {
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: expected '$3', got '$2'"
        failures=$((failures + 1))
    else
        echo "ok: $1"
    fi
}

modprobe_line() {
    cat "$1/etc/modprobe.d/carnine-audio.conf"
}

dracut_line() {
    cat "$1/etc/dracut.conf.d/carnine-audio.conf"
}

# hdmi keeps what the image always had: HDMI0 is card 0.
tree=$(mktemp -d)
sh "$SCRIPT" hdmi "$tree" > /dev/null
check "hdmi: slots" "$(modprobe_line "$tree")" "options snd slots=vc4,vc4,snd_bcm2835"
check "hdmi: initramfs gets the file" "$(dracut_line "$tree")" \
    'install_items+=" /etc/modprobe.d/carnine-audio.conf "'
rm -rf "$tree"

# jack puts snd_bcm2835 first.
tree=$(mktemp -d)
sh "$SCRIPT" jack "$tree" > /dev/null
check "jack: slots" "$(modprobe_line "$tree")" "options snd slots=snd_bcm2835,vc4,vc4"
check "jack: initramfs gets the file" "$(dracut_line "$tree")" \
    'install_items+=" /etc/modprobe.d/carnine-audio.conf "'
rm -rf "$tree"

# Running it again replaces the line instead of adding a second one.
tree=$(mktemp -d)
sh "$SCRIPT" jack "$tree" > /dev/null
sh "$SCRIPT" hdmi "$tree" > /dev/null
check "switch back: one line" "$(wc -l < "$tree/etc/modprobe.d/carnine-audio.conf" | tr -d ' ')" "1"
check "switch back: slots" "$(modprobe_line "$tree")" "options snd slots=vc4,vc4,snd_bcm2835"
rm -rf "$tree"

# Anything else fails the build and writes nothing.
for value in "" HDMI headphones; do
    tree=$(mktemp -d)
    if sh "$SCRIPT" "$value" "$tree" 2> /dev/null; then
        status=0
    else
        status=$?
    fi
    check "'$value': fails" "$status" "1"
    check "'$value': writes nothing" "$(find "$tree" -type f | wc -l | tr -d ' ')" "0"
    rm -rf "$tree"
done

if [ "$failures" -ne 0 ]; then
    echo "$failures test(s) failed"
    exit 1
fi
echo "all tests passed"
