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
#             /etc/asound.conf runs them through the volume control PCM into
#             the ALSA loopback, and carnine-ac3.service encodes them with
#             ffmpeg and sends them to HDMI0 as a non-audio IEC 61937 stream.
#             Only for such a decoder: a panel or TV that takes PCM gets no
#             sound from it.
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
aloop_load="$root/etc/modules-load.d/carnine-ac3.conf"
aloop_options="$root/etc/modprobe.d/carnine-ac3.conf"
encoder="$root/usr/local/sbin/carnine-ac3-encoder"
unit="$root/etc/systemd/system/carnine-ac3.service"
unit_link="$root/etc/systemd/system/multi-user.target.wants/carnine-ac3.service"
if [ "$output" = hdmi-ac3 ]; then
    # The backend plays four channels into the ALSA loopback; the service
    # carnine-ac3 reads them back, encodes AC-3 with ffmpeg and sends the
    # IEC 61937 frames to HDMI0 with aplay. ALSA's a52 plugin did the same
    # inside the backend but kept its audio thread polling (about a core on
    # jeep-pi, 13.10.2026); this way costs about a tenth of one.
    cat > "$asound_conf" << '__EOF__'
# Written by carnine-audio-output.sh (audio_output hdmi-ac3): four channels
# through the volume control PCM (amixer -c 0, as on plain HDMI) into the
# ALSA loopback, where the service carnine-ac3 encodes them to AC-3 for
# HDMI0. The control has the full name vc4-hdmi.conf gives it ("PCM Playback
# Volume"): with a plain "PCM" next to the restored one, amixer finds two
# and fails. The loopback runs with the format the encoder reads.
pcm.!default {
    type plug
    slave.pcm "carnine_volume"
}
pcm.carnine_volume {
    type softvol
    slave.pcm "carnine_loop"
    control {
        name "PCM Playback Volume"
        card 0
    }
}
pcm.carnine_loop {
    type plug
    slave {
        pcm "hw:CARD=Loopback,DEV=0"
        format S16_LE
        rate 48000
        channels 4
    }
}
ctl.!default {
    type hw
    card 0
}
__EOF__
    install -d "$root/etc/carnine/config.d" "$root/etc/modules-load.d" "$root/etc/modprobe.d" \
        "$root/usr/local/sbin" "$root/etc/systemd/system/multi-user.target.wants"
    printf '%s\n' '# Written by carnine-audio-output.sh (audio_output hdmi-ac3).' \
        '[audio]' 'channels = 4' > "$channels_dropin"
    printf '%s\n' '# Written by carnine-audio-output.sh (audio_output hdmi-ac3).' 'snd-aloop' > "$aloop_load"
    printf '%s\n' '# Written by carnine-audio-output.sh (audio_output hdmi-ac3).' \
        'options snd-aloop id=Loopback pcm_substreams=1' > "$aloop_options"
    cat > "$encoder" << '__EOF__'
#!/bin/sh
# Written by carnine-audio-output.sh (audio_output hdmi-ac3): reads the
# backend's four channels from the ALSA loopback, encodes AC-3 (448 kbit/s)
# and sends it to HDMI0 as non-audio IEC 61937. Run by carnine-ac3.service.
# The four channels are front left/right and rear left/right ("quad", AC-3
# mode 2/2); ffmpeg would guess "4.0" (centre and one rear) for them.
# CARNINE_AC3_INPUT / CARNINE_AC3_OUTPUT change the devices (tests).
set -eu
input=${CARNINE_AC3_INPUT:-hw:CARD=Loopback,DEV=1}
output=${CARNINE_AC3_OUTPUT:-hdmi:CARD=vc4hdmi0,AES0=0x06}
ffmpeg -nostdin -hide_banner -loglevel warning \
    -f alsa -channels 4 -sample_rate 48000 -i "$input" \
    -af channelmap=channel_layout=quad \
    -c:a ac3 -b:a 448k -f spdif - |
    aplay -q -D "$output" -t raw -f S16_LE -c 2 -r 48000 \
        --buffer-time=200000 --period-time=50000
__EOF__
    chmod 0755 "$encoder"
    cat > "$unit" << '__EOF__'
# Written by carnine-audio-output.sh (audio_output hdmi-ac3).
[Unit]
Description=Carnine AC-3 encoder (ALSA loopback to HDMI0)
After=sound.target alsa-restore.service

[Service]
User=carnine
Group=carnine
SupplementaryGroups=audio
ExecStart=/usr/local/sbin/carnine-ac3-encoder
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
__EOF__
    ln -sf /etc/systemd/system/carnine-ac3.service "$unit_link"
    echo "AC-3 to HDMI0 over the loopback: $asound_conf, $channels_dropin, carnine-ac3.service"
else
    # Switching back from hdmi-ac3 must not leave its files behind.
    rm -f "$asound_conf" "$channels_dropin" "$aloop_load" "$aloop_options" "$encoder" \
        "$unit" "$unit_link"
fi
