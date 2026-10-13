#!/bin/sh
# Picks which output becomes ALSA card 0 at image build time (#64). The
# backend plays on the default device and sets the volume with
# `amixer -c 0 set PCM`, both of which follow card 0. Which card that is
# otherwise depends on the order vc4 (HDMI) and snd_bcm2835 (jack) load, so
# `slots` of the ALSA core module snd reserves the places per driver:
#
#   hdmi      HDMI0 card 0, HDMI1 card 1, jack card 2 (default)
#   jack      jack card 0, HDMI0 card 1, HDMI1 card 2 - for a panel without
#             speakers such as the Waveshare 7C
#   hdmi-ac3  as hdmi, but the sound leaves HDMI0 as AC-3 for a 5.1
#             decoder (e.g. an HDMI audio extractor in front of the panel):
#             the backend plays four channels (`[audio] channels = 4`,
#             front with the announcements, rear the music at full level),
#             /etc/asound.conf runs them through the volume control PCM and
#             the a52 encoder (package libasound2-plugins) to HDMI0 as a
#             non-audio IEC 61937 stream. Only for such a decoder: a panel
#             or TV that takes PCM gets no sound from it.
#
# snd loads from the initramfs together with vc4, and dracut does not take
# /etc/modprobe.d along with hostonly=no, hence install_items; the recipe
# rebuilds the initramfs later. docs/07-deployment.md, "Audio output".
#
# Usage: carnine-audio-output.sh hdmi|jack|hdmi-ac3 [ROOT]

set -eu

output=${1:-}
root=${2:-}

case "$output" in
    hdmi | hdmi-ac3) slots=vc4,vc4,snd_bcm2835 ;;
    jack) slots=snd_bcm2835,vc4,vc4 ;;
    *)
        echo "ERROR: audio_output must be hdmi, jack or hdmi-ac3, not '$output'" >&2
        exit 1
        ;;
esac

install -d "$root/etc/modprobe.d" "$root/etc/dracut.conf.d"
printf 'options snd slots=%s\n' "$slots" > "$root/etc/modprobe.d/carnine-audio.conf"
printf '%s\n' 'install_items+=" /etc/modprobe.d/carnine-audio.conf "' \
    > "$root/etc/dracut.conf.d/carnine-audio.conf"
echo "ALSA card 0: $output (slots=$slots)"

asound_conf="$root/etc/asound.conf"
channels_dropin="$root/etc/carnine/config.d/20-audio-ac3.toml"
if [ "$output" = hdmi-ac3 ]; then
    cat > "$asound_conf" << '__EOF__'
# Written by carnine-audio-output.sh (audio_output hdmi-ac3): four channels
# through the volume control PCM (amixer -c 0, as on plain HDMI) and the
# AC-3 encoder to HDMI0, AES0=0x06 marks the stream as non-audio.
pcm.!default {
    type plug
    slave.pcm "carnine_volume"
}
pcm.carnine_volume {
    type softvol
    slave.pcm "carnine_ac3"
    control {
        name "PCM"
        card 0
    }
}
pcm.carnine_ac3 {
    type a52
    slavepcm "hdmi:CARD=vc4hdmi0,AES0=0x06"
    channels 4
    rate 48000
    bitrate 448
}
ctl.!default {
    type hw
    card 0
}
__EOF__
    install -d "$root/etc/carnine/config.d"
    printf '%s\n' '# Written by carnine-audio-output.sh (audio_output hdmi-ac3).' \
        '[audio]' 'channels = 4' > "$channels_dropin"
    echo "AC-3 to HDMI0: $asound_conf, $channels_dropin"
else
    # Switching back from hdmi-ac3 must not leave its files behind.
    rm -f "$asound_conf" "$channels_dropin"
fi
