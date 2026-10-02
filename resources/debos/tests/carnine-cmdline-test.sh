#!/bin/sh
# Tests for carnine-cmdline.sh on a scratch tree; no root needed.

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/carnine-cmdline.sh"
failures=0

check() {
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: expected '$3', got '$2'"
        failures=$((failures + 1))
    else
        echo "ok: $1"
    fi
}

cmdline() {
    cat "$1/boot/firmware/cmdline.txt"
}

base='root=LABEL=ROOTFS quiet splash logo.nologo'
tail_part='vt.global_cursor_default=1 pinctrl_bcm2835.persist_gpio_outputs=n'

# The 7H images keep the EDID Waveshare sent.
tree=$(mktemp -d)
sh "$SCRIPT" waveshare-1024x600 7h "$tree" > /dev/null
check "7h: forces the 7H EDID" "$(cmdline "$tree")" \
    "$base drm.edid_firmware=HDMI-A-1:edid/waveshare-7h-260929.bin $tail_part"
check "7h: one line" "$(wc -l < "$tree/boot/firmware/cmdline.txt" | tr -d ' ')" "1"
rm -rf "$tree"

# The 7C image lets the panel's own EDID count.
tree=$(mktemp -d)
sh "$SCRIPT" waveshare-1024x600 none "$tree" > /dev/null
check "none: no EDID forced" "$(cmdline "$tree")" "$base $tail_part"
rm -rf "$tree"

# Without the Waveshare profile there is nothing to force either.
tree=$(mktemp -d)
sh "$SCRIPT" auto 7h "$tree" > /dev/null
check "auto: no EDID forced" "$(cmdline "$tree")" "$base $tail_part"
rm -rf "$tree"

# Anything else stops the build.
tree=$(mktemp -d)
if sh "$SCRIPT" waveshare-1024x600 7c "$tree" 2> /dev/null; then
    check "unknown edid stops the build" "succeeded" "failed"
else
    check "unknown edid stops the build" "failed" "failed"
fi
check "unknown edid writes nothing" "$(ls -A "$tree")" ""
rm -rf "$tree"

if [ "$failures" -ne 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "all checks passed"
