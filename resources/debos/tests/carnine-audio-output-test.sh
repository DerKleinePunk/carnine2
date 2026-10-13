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

# hdmi-ac3 keeps HDMI0 as card 0 and adds the loopback, the encoder service
# and four channels.
tree=$(mktemp -d)
sh "$SCRIPT" hdmi-ac3 "$tree" > /dev/null
check "hdmi-ac3: slots" "$(modprobe_line "$tree")" "options snd slots=vc4,vc4,snd_bcm2835"
check "hdmi-ac3: default goes through the volume control" \
    "$(grep -c 'slave.pcm "carnine_volume"' "$tree/etc/asound.conf")" "1"
check "hdmi-ac3: the same volume control as plain HDMI (one PCM for amixer)" \
    "$(grep -A3 'control {' "$tree/etc/asound.conf" | tr '\n' ' ' | tr -s ' ')" \
    ' control { name "PCM Playback Volume" card 0 } '
check "hdmi-ac3: into the loopback in the encoder's format" \
    "$(grep -A5 'slave {' "$tree/etc/asound.conf" | tr '\n' ' ' | tr -s ' ')" \
    ' slave { pcm "hw:CARD=Loopback,DEV=0" format S16_LE rate 48000 channels 4 } '
check "hdmi-ac3: no a52 any more" "$(grep -c a52 "$tree/etc/asound.conf")" "0"
check "hdmi-ac3: backend opens four channels" \
    "$(grep -v '^#' "$tree/etc/carnine/config.d/20-audio-ac3.toml" | tr '\n' ' ')" '[audio] channels = 4 '
check "hdmi-ac3: loopback loaded at boot" "$(grep -v '^#' "$tree/etc/modules-load.d/carnine-ac3.conf")" "snd-aloop"
check "hdmi-ac3: loopback named for the configs" \
    "$(grep -v '^#' "$tree/etc/modprobe.d/carnine-ac3.conf")" "options snd-aloop id=Loopback pcm_substreams=1"
check "hdmi-ac3: encoder executable" "$(test -x "$tree/usr/local/sbin/carnine-ac3-encoder" && echo yes)" "yes"
check "hdmi-ac3: encoder reads the loopback" \
    "$(grep -c 'CARNINE_AC3_INPUT:-hw:CARD=Loopback,DEV=1' "$tree/usr/local/sbin/carnine-ac3-encoder")" "1"
check "hdmi-ac3: encoder takes the four channels as front and rear pairs" \
    "$(grep -c 'channelmap=channel_layout=quad' "$tree/usr/local/sbin/carnine-ac3-encoder")" "1"
check "hdmi-ac3: encoder writes HDMI0 as non-audio" \
    "$(grep -c 'CARNINE_AC3_OUTPUT:-hdmi:CARD=vc4hdmi0,AES0=0x06' "$tree/usr/local/sbin/carnine-ac3-encoder")" "1"
check "hdmi-ac3: service runs the encoder as carnine" \
    "$(grep -E '^(User|ExecStart)=' "$tree/etc/systemd/system/carnine-ac3.service" | tr '\n' ' ')" \
    'User=carnine ExecStart=/usr/local/sbin/carnine-ac3-encoder '
check "hdmi-ac3: service enabled" \
    "$(readlink "$tree/etc/systemd/system/multi-user.target.wants/carnine-ac3.service")" \
    "/etc/systemd/system/carnine-ac3.service"
# Back to hdmi removes every file again.
sh "$SCRIPT" hdmi "$tree" > /dev/null
for file in etc/asound.conf etc/carnine/config.d/20-audio-ac3.toml etc/modules-load.d/carnine-ac3.conf \
    etc/modprobe.d/carnine-ac3.conf usr/local/sbin/carnine-ac3-encoder \
    etc/systemd/system/carnine-ac3.service etc/systemd/system/multi-user.target.wants/carnine-ac3.service; do
    check "hdmi after hdmi-ac3: no $file" \
        "$(test -e "$tree/$file" -o -L "$tree/$file" && echo there || echo gone)" "gone"
done
rm -rf "$tree"

# Anything else fails the build and writes nothing.
for value in "" HDMI headphones ac3; do
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
