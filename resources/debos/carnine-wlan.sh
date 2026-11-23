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
#   --interface <name>                 that WLAN device, e.g. a USB stick
#                                      beside the built-in one; default the
#                                      first wl* device
#   --band 5|any                       5: store the network for 5 GHz only
#                                      (freq_list), any: as before; default
#                                      from BAND= in /etc/carnine/wlan.conf,
#                                      else any
#
# BAND=5 is for a WLAN stick that is poor on 2.4 GHz and a phone hotspot set
# to 5 GHz. The scan list shows each network's band; a network seen only on
# 2.4 GHz is refused with BAND=5 before the password is asked. The band
# applies to a network when it is stored; set it up again to change it.
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
WLAN_CONF=${CARNINE_WLAN_CONF:-/etc/carnine/wlan.conf}
SYSTEMCTL=${CARNINE_SYSTEMCTL:-systemctl}
RFKILL=${CARNINE_RFKILL:-rfkill}
WPA_CLI=${CARNINE_WPA_CLI:-wpa_cli}
WPA_PASSPHRASE=${CARNINE_WPA_PASSPHRASE:-wpa_passphrase}
IP=${CARNINE_IP:-ip}
# The scan is read every SCAN_STEP seconds until it has been stable for two
# reads, then scanned once more (a stick finds more on the second pass);
# SCAN_MAX reads at most. A fixed wait was too short for a USB stick right
# after wpa_supplicant started (jeep-pi, 2026-11-23).
SCAN_STEP=${CARNINE_SCAN_STEP:-1}
SCAN_MAX=${CARNINE_SCAN_MAX:-15}
ADDRESS_WAIT=${CARNINE_ADDRESS_WAIT:-30}
CONTROL_WAIT=${CARNINE_CONTROL_WAIT:-10}

MODE=on
SSID=""
interface=""
COUNTRY=DE
BAND=""
# Every 5 GHz channel (36-64, 100-144, 149-177); wpa_supplicant leaves out
# what the country or the adapter does not allow.
FREQS_5GHZ="5180 5200 5220 5240 5260 5280 5300 5320 5500 5520 5540 5560 5580 5600 5620 5640 5660 5680 5700 5720 5745 5765 5785 5805 5825 5845 5865 5885"

die() {
    echo "FEHLER: $*" >&2
    exit 1
}

usage() {
    die "Aufruf: sudo carnine-wlan [--ssid <name>] [--country <XX>] [--band 5|any] [--interface <name>] | --on | --off | --status"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --ssid) [ $# -ge 2 ] || usage; SSID=$2; shift 2 ;;
        --country) [ $# -ge 2 ] || usage; COUNTRY=$2; shift 2 ;;
        --band) [ $# -ge 2 ] || usage; BAND=$2; shift 2 ;;
        --interface) [ $# -ge 2 ] || usage; interface=$2; shift 2 ;;
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
# The file is read, not sourced: only BAND= counts, quotes are dropped.
if [ -z "$BAND" ] && [ -r "$WLAN_CONF" ]; then
    BAND=$(sed -n 's/^[[:space:]]*BAND=["'"'"']\{0,1\}\([^"'"'"' ]*\).*/\1/p' "$WLAN_CONF" | tail -n 1)
fi
BAND=${BAND:-any}
case "$BAND" in
    5|any) ;;
    *) die "Band 5 oder any: $BAND" ;;
esac

if [ -n "$interface" ]; then
    case "$interface" in
        */*|.*) die "kein WLAN-Gerät $interface" ;;
    esac
    [ -e "$NET_DIR/$interface" ] || die "kein WLAN-Gerät $interface"
else
    for path in "$NET_DIR"/wl*; do
        [ -e "$path" ] || continue
        interface=${path##*/}
        break
    done
    [ -n "$interface" ] || die "kein WLAN-Gerät gefunden"
fi
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
        "$WPA_CLI" -i "$interface" status 2>/dev/null | grep -E '^(ssid|freq|wpa_state)=' || echo "wpa_state=AUS"
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

# scan_networks: every network in range, strongest first, each name once,
# as "name<TAB>bands" with the bands it was seen on ("2,4", "5", "2,4+5").
scan_networks() {
    "$WPA_CLI" -i "$interface" scan > /dev/null
    rescanned=no
    last=""
    same=0
    reads=0
    while [ "$reads" -lt "$SCAN_MAX" ]; do
        sleep "$SCAN_STEP"
        reads=$((reads + 1))
        now=$("$WPA_CLI" -i "$interface" scan_results | awk 'NR > 1' | wc -l)
        if [ "$now" -gt 0 ] && [ "$now" = "$last" ]; then same=$((same + 1)); else same=0; fi
        last=$now
        if [ "$same" -ge 2 ]; then
            [ "$rescanned" = yes ] && break
            "$WPA_CLI" -i "$interface" scan > /dev/null
            rescanned=yes
            same=0
        fi
    done
    "$WPA_CLI" -i "$interface" scan_results |
        awk -F '\t' 'NR > 1 && $5 != "" {
            band = ($2 >= 4900) ? "5" : "2,4"
            if (!($5 in best) || $3 > best[$5]) best[$5] = $3
            if (band == "5") five[$5] = 1; else two[$5] = 1
        }
        END {
            for (name in best) {
                bands = (name in two) ? ((name in five) ? "2,4+5" : "2,4") : "5"
                print best[name] "\t" name "\t" bands
            }
        }' | sort -t "$(printf '\t')" -k1,1nr | cut -f 2-
}

networks=""
if [ -z "$SSID" ]; then
    echo "Suche Netze ..."
    networks=$(scan_networks)
    if [ -z "$networks" ]; then
        die "kein Netz gefunden. Versteckte Netze mit: sudo carnine-wlan --ssid <name>"
    fi
    printf '%s\n' "$networks" | head -n 20 | awk -F '\t' '{ printf "  %2d  %s  (%s GHz)\n", NR, $1, $2 }'
    if [ "$BAND" = 5 ]; then
        echo "Nur Netze auf 5 GHz (BAND=5)."
    fi
    printf 'Nummer oder Name des Netzes: '
    read -r choice || die "kein Netz gewählt"
    case "$choice" in
        ''|*[!0-9]*) SSID=$choice ;;
        *) SSID=$(printf '%s\n' "$networks" | head -n 20 | sed -n "${choice}p" | cut -f 1) ;;
    esac
    [ -n "$SSID" ] || die "kein Netz mit der Nummer $choice"
elif [ "$BAND" = 5 ]; then
    # A name given directly is checked too; one that is not seen at all is a
    # hidden network and is stored as asked.
    echo "Prüfe das Band von '$SSID' ..."
    networks=$(scan_networks)
fi

# With BAND=5, a network seen only on 2.4 GHz is refused before the
# password, whether it came from the list, was typed or given with --ssid.
if [ "$BAND" = 5 ]; then
    bands=$(printf '%s\n' "$networks" | awk -F '\t' -v name="$SSID" '$1 == name { print $2; exit }')
    if [ "$bands" = "2,4" ]; then
        die "'$SSID' ist nur auf 2,4 GHz zu sehen, dieses Gerät nimmt nur 5 GHz (BAND=5). Hotspot am Handy auf 5 GHz stellen und noch einmal aufrufen, oder einmalig mit --band any."
    fi
    if [ -z "$bands" ]; then
        echo "'$SSID' ist nicht zu sehen; wird als verstecktes Netz für 5 GHz gespeichert."
    fi
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
    block=$(printf 'network={\n\tssid=%s\n\tpsk=%s\n\tkey_mgmt=WPA-PSK\n' "$ssid_hex" "$psk")
else
    block=$(printf 'network={\n\tssid=%s\n\tkey_mgmt=NONE\n' "$ssid_hex")
fi
if [ "$BAND" = 5 ]; then
    block=$(printf '%s\n\tfreq_list=%s\n' "$block" "$FREQS_5GHZ")
fi
block=$(printf '%s\n}' "$block")

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

if [ "$BAND" = 5 ]; then
    echo "Verbinde mit '$SSID' (nur 5 GHz) ..."
else
    echo "Verbinde mit '$SSID' ..."
fi
wait_for_address "Passwort falsch oder Netz zu weit weg? Noch einmal aufrufen."
