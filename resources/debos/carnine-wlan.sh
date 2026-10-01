#!/bin/sh
# Connects the device to a WLAN: sudo carnine-wlan. Installed as
# /usr/local/sbin/carnine-wlan. The image sets up no WLAN; systemd-networkd
# already runs DHCP on every wl* interface, so all that is missing is
# wpa_supplicant with a network. This unblocks WLAN, starts
# wpa_supplicant@<interface>, scans, asks for the network and its password
# and waits for an address.
#
#   sudo carnine-wlan                  choose from the networks in range
#   sudo carnine-wlan --ssid <name>    a network by name, also a hidden one
#   sudo carnine-wlan --status         show the connection
#   sudo carnine-wlan --off            switch WLAN off again
#   sudo carnine-wlan --on             on again with the stored networks, no questions
#   --country <XX>                     regulatory domain, default DE
#
# Only the key derived from the password is stored (wpa_passphrase), not the
# password itself. A network that is set up again replaces its old entry;
# others stay, so the device also finds e.g. a phone's hotspot again.
#
# The paths and commands can be overridden so the tests can run it on a
# scratch tree.

set -eu

NET_DIR=${CARNINE_NET_DIR:-/sys/class/net}
WPA_DIR=${CARNINE_WPA_DIR:-/etc/wpa_supplicant}
SYSTEMCTL=${CARNINE_SYSTEMCTL:-systemctl}
RFKILL=${CARNINE_RFKILL:-rfkill}
WPA_CLI=${CARNINE_WPA_CLI:-wpa_cli}
WPA_PASSPHRASE=${CARNINE_WPA_PASSPHRASE:-wpa_passphrase}
IP=${CARNINE_IP:-ip}
SCAN_WAIT=${CARNINE_SCAN_WAIT:-4}
ADDRESS_WAIT=${CARNINE_ADDRESS_WAIT:-30}
CONTROL_WAIT=${CARNINE_CONTROL_WAIT:-10}

MODE=on
SSID=""
COUNTRY=DE

die() {
    echo "FEHLER: $*" >&2
    exit 1
}

usage() {
    die "Aufruf: sudo carnine-wlan [--ssid <name>] [--country <XX>] | --on | --off | --status"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ssid) [ $# -ge 2 ] || usage; SSID=$2; shift 2 ;;
        --country) [ $# -ge 2 ] || usage; COUNTRY=$2; shift 2 ;;
        --status) MODE=status; shift ;;
        --off) MODE=off; shift ;;
        --on) MODE=resume; shift ;;
        *) usage ;;
    esac
done

if [ "$(id -u)" -ne 0 ] && [ -z "${CARNINE_SKIP_ROOT_CHECK:-}" ]; then
    die "bitte mit sudo aufrufen: sudo carnine-wlan"
fi
printf '%s' "$COUNTRY" | grep -Eqx '[A-Z]{2}' || die "Land als zwei Großbuchstaben, z. B. DE, AT oder CH: $COUNTRY"

interface=""
for path in "$NET_DIR"/wl*; do
    [ -e "$path" ] || continue
    interface=${path##*/}
    break
done
[ -n "$interface" ] || die "kein WLAN-Gerät gefunden"
CONF="$WPA_DIR/wpa_supplicant-$interface.conf"
SERVICE="wpa_supplicant@$interface.service"

address() {
    "$IP" -4 -o addr show dev "$interface" 2>/dev/null | awk '{ split($4, a, "/"); print a[1]; exit }'
}

# start_wpa_supplicant <systemctl action...>: wpa_supplicant opens its
# control socket a moment after systemctl returns; until then every wpa_cli
# call fails.
start_wpa_supplicant() {
    "$SYSTEMCTL" "$@" "$SERVICE"
    waited=0
    until "$WPA_CLI" -i "$interface" ping 2>/dev/null | grep -q PONG; do
        if [ "$waited" -ge "$CONTROL_WAIT" ]; then
            die "wpa_supplicant antwortet nicht. Stand: systemctl status $SERVICE"
        fi
        sleep 1
        waited=$((waited + 1))
    done
}

wait_for_address() {
    waited=0
    while [ "$waited" -lt "$ADDRESS_WAIT" ]; do
        found=$(address)
        if [ -n "$found" ]; then
            echo "Verbunden, Adresse $found."
            exit 0
        fi
        sleep 1
        waited=$((waited + 1))
    done
    die "nach $ADDRESS_WAIT s keine Adresse. $1 Stand: sudo carnine-wlan --status"
}

case "$MODE" in
    off)
        "$SYSTEMCTL" disable --now "$SERVICE"
        echo "WLAN ist aus. Die gespeicherten Netze bleiben in $CONF."
        exit 0
        ;;
    status)
        "$WPA_CLI" -i "$interface" status 2>/dev/null | grep -E '^(ssid|wpa_state)=' || echo "wpa_state=AUS"
        echo "Adresse: $(address)"
        exit 0
        ;;
    resume)
        grep -q '^network=' "$CONF" 2>/dev/null || die "noch kein Netz eingerichtet: sudo carnine-wlan"
        "$RFKILL" unblock wifi
        start_wpa_supplicant enable --now
        echo "WLAN ist wieder an, mit den gespeicherten Netzen ..."
        wait_for_address "Ist eines der gespeicherten Netze in Reichweite?"
        ;;
esac

# Setting up a network only starts wpa_supplicant for the scan; it is enabled
# once the network is stored. A run that stops before (no network found, a
# short password, Ctrl+C) leaves it as it was and the terminal echoing again.
was_active=no
if "$SYSTEMCTL" is-active --quiet "$SERVICE"; then was_active=yes; fi
stored=no
# shellcheck disable=SC2317 # called by the EXIT trap
cleanup() {
    if [ -t 0 ]; then stty echo; fi
    if [ "$stored" = no ] && [ "$was_active" = no ]; then
        "$SYSTEMCTL" stop "$SERVICE" || true
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

"$RFKILL" unblock wifi
mkdir -p "$WPA_DIR"
if [ ! -e "$CONF" ]; then
    printf 'ctrl_interface=DIR=/run/wpa_supplicant GROUP=netdev\nupdate_config=1\ncountry=%s\n' "$COUNTRY" > "$CONF"
elif grep -q '^country=' "$CONF"; then
    sed -i "s/^country=.*/country=$COUNTRY/" "$CONF"
else
    printf 'country=%s\n' "$COUNTRY" >> "$CONF"
fi
chmod 0600 "$CONF"
start_wpa_supplicant start

# Networks in range, strongest first, each name once.
if [ -z "$SSID" ]; then
    echo "Suche Netze ..."
    "$WPA_CLI" -i "$interface" scan > /dev/null
    sleep "$SCAN_WAIT"
    list=$("$WPA_CLI" -i "$interface" scan_results |
        awk -F '\t' 'NR > 1 && $5 != "" { print $3 "\t" $5 }' | sort -t "$(printf '\t')" -k1,1nr |
        awk -F '\t' '!seen[$2]++ { print $2 }' | head -n 20)
    if [ -z "$list" ]; then
        die "kein Netz gefunden. Versteckte Netze mit: sudo carnine-wlan --ssid <name>"
    fi
    printf '%s\n' "$list" | awk '{ printf "  %2d  %s\n", NR, $0 }'
    printf 'Nummer oder Name des Netzes: '
    read -r choice || die "kein Netz gewählt"
    case "$choice" in
        ''|*[!0-9]*) SSID=$choice ;;
        *) SSID=$(printf '%s\n' "$list" | sed -n "${choice}p") ;;
    esac
    [ -n "$SSID" ] || die "kein Netz mit der Nummer $choice"
fi

printf "Passwort für '%s' (leer für ein offenes Netz): " "$SSID"
if [ -t 0 ]; then stty -echo; fi
password=""
read -r password || die "abgebrochen, kein Netz gespeichert"
if [ -t 0 ]; then stty echo; echo; fi

# The name as hex, so that quotes or other odd characters in it are safe.
ssid_hex=$(printf '%s' "$SSID" | od -An -tx1 | tr -d ' \n')
if [ -n "$password" ]; then
    if [ ${#password} -lt 8 ] || [ ${#password} -gt 63 ]; then
        die "ein WLAN-Passwort hat 8 bis 63 Zeichen"
    fi
    psk=$("$WPA_PASSPHRASE" "$SSID" "$password" | sed -n 's/^[[:space:]]*psk=\([0-9a-f]\{64\}\)$/\1/p')
    [ -n "$psk" ] || die "wpa_passphrase hat keinen Schlüssel geliefert"
    block=$(printf 'network={\n\tssid=%s\n\tpsk=%s\n\tkey_mgmt=WPA-PSK\n}' "$ssid_hex" "$psk")
else
    block=$(printf 'network={\n\tssid=%s\n\tkey_mgmt=NONE\n}' "$ssid_hex")
fi

# Replace an older entry of the same network, keep the others.
awk -v ssid="ssid=$ssid_hex" '
    /^network=\{/ { inblock = 1; buffer = $0 "\n"; mine = 0; next }
    inblock { buffer = buffer $0 "\n"; if ($1 == ssid) mine = 1
              if ($0 ~ /^\}/) { if (!mine) printf "%s", buffer; inblock = 0 }; next }
    { print }' "$CONF" > "$CONF.new"
printf '%s\n' "$block" >> "$CONF.new"
chmod 0600 "$CONF.new"
mv "$CONF.new" "$CONF"
stored=yes
"$WPA_CLI" -i "$interface" reconfigure > /dev/null
"$SYSTEMCTL" enable "$SERVICE"

echo "Verbinde mit '$SSID' ..."
wait_for_address "Passwort falsch oder Netz zu weit weg? Noch einmal aufrufen."
