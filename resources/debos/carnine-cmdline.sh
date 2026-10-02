#!/bin/sh
# Writes the kernel command line of the image (/boot/firmware/cmdline.txt).
#
# The Waveshare 7H brings a cloned EDID with odd 1024x600 timings that the
# vc4 driver rejects, so for display=waveshare-1024x600 the image forces the
# EDID Waveshare sent (7H-260929, docs/22). The Waveshare 7C has a clean EDID
# of its own and flickers under the 7H one; its image takes edid=none and
# lets the panel speak for itself (Jonas, 2 October 2026).
#
# pinctrl_bcm2835.persist_gpio_outputs=n: a GPIO line the backend lets go of
# (it exits or crashes) falls back to an input instead of keeping its level,
# so the pull-down on the IO board's /RESET turns all relays off (Technik
# page, reset_gpio).
#
# Usage: carnine-cmdline.sh <display> 7h|none [ROOT]

set -eu

display=${1:-}
edid=${2:-}
root=${3:-}

case "$edid" in
    7h) edid_file=edid/waveshare-7h-260929.bin ;;
    none) edid_file= ;;
    *)
        echo "ERROR: edid must be 7h or none, not '$edid'" >&2
        exit 1
        ;;
esac

line='root=LABEL=ROOTFS quiet splash logo.nologo'
if [ "$display" = waveshare-1024x600 ] && [ -n "$edid_file" ]; then
    line="$line drm.edid_firmware=HDMI-A-1:$edid_file"
fi
line="$line vt.global_cursor_default=1 pinctrl_bcm2835.persist_gpio_outputs=n"

install -d "$root/boot/firmware"
printf '%s\n' "$line" > "$root/boot/firmware/cmdline.txt"
echo "cmdline: $line"
