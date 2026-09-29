#!/bin/sh
# Picks which output becomes ALSA card 0 at image build time (#64). The
# backend plays on the default device and sets the volume with
# `amixer -c 0 set PCM`, both of which follow card 0. Which card that is
# otherwise depends on the order vc4 (HDMI) and snd_bcm2835 (jack) load, so
# `slots` of the ALSA core module snd reserves the places per driver:
#
#   hdmi  HDMI0 card 0, HDMI1 card 1, jack card 2 (default)
#   jack  jack card 0, HDMI0 card 1, HDMI1 card 2 - for a panel without
#         speakers such as the Waveshare 7C
#
# snd loads from the initramfs together with vc4, and dracut does not take
# /etc/modprobe.d along with hostonly=no, hence install_items; the recipe
# rebuilds the initramfs later. docs/07-deployment.md, "Audio output".
#
# Usage: carnine-audio-output.sh hdmi|jack [ROOT]

set -eu

output=${1:-}
root=${2:-}

case "$output" in
    hdmi) slots=vc4,vc4,snd_bcm2835 ;;
    jack) slots=snd_bcm2835,vc4,vc4 ;;
    *)
        echo "ERROR: audio_output must be hdmi or jack, not '$output'" >&2
        exit 1
        ;;
esac

install -d "$root/etc/modprobe.d" "$root/etc/dracut.conf.d"
printf 'options snd slots=%s\n' "$slots" > "$root/etc/modprobe.d/carnine-audio.conf"
printf '%s\n' 'install_items+=" /etc/modprobe.d/carnine-audio.conf "' \
    > "$root/etc/dracut.conf.d/carnine-audio.conf"
echo "ALSA card 0: $output (slots=$slots)"
