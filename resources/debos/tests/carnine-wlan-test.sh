#!/bin/sh
# Tests for carnine-wlan.sh on a scratch tree, with stand-ins for wpa_cli,
# wpa_passphrase, ip, systemctl and rfkill; no root and no WLAN needed.
# The generated stand-ins use $1 and $2 of their own.
# shellcheck disable=SC2016

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/carnine-wlan.sh"
failures=0
TAB=$(printf '\t')

setup() {
    tree=$(mktemp -d)
    mkdir -p "$tree/net/wlan0" "$tree/net/eth0" "$tree/wpa"
    : > "$tree/calls.log"
    # Three networks in range, one of them seen twice; the strongest is "Garage".
    printf 'bssid / frequency / signal level / flags / ssid\n' > "$tree/scan.txt"
    printf '%s\n' "aa:01${TAB}2412${TAB}-70${TAB}[WPA2-PSK-CCMP]${TAB}Nachbar" \
        "aa:02${TAB}2437${TAB}-40${TAB}[WPA2-PSK-CCMP]${TAB}Garage" \
        "aa:03${TAB}5180${TAB}-55${TAB}[WPA2-PSK-CCMP]${TAB}Handy" \
        "aa:04${TAB}2462${TAB}-80${TAB}[WPA2-PSK-CCMP]${TAB}Garage" \
        "aa:05${TAB}2462${TAB}-60${TAB}[ESS]${TAB}" >> "$tree/scan.txt"
    cat > "$tree/fake-wpa_cli" <<EOF
#!/bin/sh
echo "wpa_cli \$*" >> "$tree/calls.log"
case "\$3" in
    # ping-late holds how many pings still go unanswered, as right after start.
    ping)
        late=\$(cat "$tree/ping-late" 2>/dev/null || echo 0)
        if [ "\$late" -gt 0 ]; then echo \$((late - 1)) > "$tree/ping-late"; exit 1; fi
        echo PONG ;;
    scan_results) cat "$tree/scan.txt" ;;
    reconfigure) [ -e "$tree/no-address" ] || : > "$tree/connected" ;;
    status) printf 'ssid=Garage\nwpa_state=COMPLETED\n' ;;
esac
EOF
    # A stand-in key: the real one is PBKDF2 of name and password.
    cat > "$tree/fake-wpa_passphrase" <<'EOF'
#!/bin/sh
printf 'network={\n\tssid="%s"\n\t#psk="%s"\n\tpsk=%s\n}\n' "$1" "$2" "$(printf '%s:%s' "$1" "$2" | sha256sum | cut -c1-64)"
EOF
    cat > "$tree/fake-ip" <<EOF
#!/bin/sh
[ -e "$tree/connected" ] && echo "3: wlan0    inet 192.168.2.77/24 brd 192.168.2.255 scope global dynamic wlan0"
exit 0
EOF
    # Starting wpa_supplicant with a stored network brings an address.
    cat > "$tree/fake-systemctl" <<EOF
#!/bin/sh
echo "systemctl \$*" >> "$tree/calls.log"
if [ "\$1" = enable ] && [ ! -e "$tree/no-address" ] &&
    grep -q '^network=' "$tree/wpa/wpa_supplicant-wlan0.conf" 2>/dev/null; then
    : > "$tree/connected"
fi
EOF
    printf '#!/bin/sh\necho "rfkill $*" >> "%s/calls.log"\n' "$tree" > "$tree/fake-rfkill"
    chmod +x "$tree"/fake-*
}

# run <input> <arguments...>; the exit code lands in $status.
run() {
    input=$1
    shift
    status=0
    printf '%b' "$input" | CARNINE_NET_DIR="$tree/net" CARNINE_WPA_DIR="$tree/wpa" \
        CARNINE_SYSTEMCTL="$tree/fake-systemctl" CARNINE_RFKILL="$tree/fake-rfkill" \
        CARNINE_WPA_CLI="$tree/fake-wpa_cli" CARNINE_WPA_PASSPHRASE="$tree/fake-wpa_passphrase" \
        CARNINE_IP="$tree/fake-ip" CARNINE_SCAN_WAIT=0 CARNINE_ADDRESS_WAIT=2 CARNINE_CONTROL_WAIT=3 CARNINE_SKIP_ROOT_CHECK=1 \
        sh "$SCRIPT" "$@" > "$tree/out.log" 2>&1 || status=$?
}

conf() {
    cat "$tree/wpa/wpa_supplicant-wlan0.conf"
}

hex() {
    printf '%s' "$1" | od -An -tx1 | tr -d ' \n'
}

check() {
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: expected '$3', got '$2'"
        sed 's/^/    | /' "$tree/out.log"
        failures=$((failures + 1))
    else
        echo "ok: $1"
    fi
}

# Choose by number: the list is strongest first, each name once.
setup
run '1\ngeheim123\n'
check "connect succeeds" "$status" "0"
check "list strongest first, no doubles" "$(grep -E '^ +[0-9]+  ' "$tree/out.log" | awk '{ print $2 }' | tr '\n' ' ')" "Garage Handy Nachbar "
check "address shown" "$(grep -c 'Verbunden, Adresse 192.168.2.77' "$tree/out.log")" "1"
check "WLAN unblocked" "$(grep -c '^rfkill unblock wifi$' "$tree/calls.log")" "1"
check "wpa_supplicant started" "$(grep -c '^systemctl enable --now wpa_supplicant@wlan0.service$' "$tree/calls.log")" "1"
check "country set" "$(conf | grep '^country=')" "country=DE"
check "network stored as hex" "$(conf | grep -c "ssid=$(hex Garage)$")" "1"
check "key stored" "$(conf | grep -c "psk=$(printf 'Garage:geheim123' | sha256sum | cut -c1-64)$")" "1"
check "password not stored" "$(conf | grep -c geheim123)" "0"
check "config only for root" "$(stat -c %a "$tree/wpa/wpa_supplicant-wlan0.conf")" "600"
check "reconfigured" "$(grep -c 'reconfigure' "$tree/calls.log")" "1"

# A second network by name joins the first; the first again replaces itself.
run 'Handy\nhotspot99\n'
check "second network kept beside the first" "$(conf | grep -c '^network={')" "2"
run '1\nneues-passwort\n'
check "same network replaced, not doubled" "$(conf | grep -c "ssid=$(hex Garage)$")" "1"
check "replaced with the new key" "$(conf | grep -c "psk=$(printf 'Garage:neues-passwort' | sha256sum | cut -c1-64)$")" "1"
check "two networks in all" "$(conf | grep -c '^network={')" "2"
check "header kept once" "$(conf | grep -c '^ctrl_interface=')" "1"
rm -rf "$tree"

# An open network: empty password.
setup
run '\n' --ssid Gast
check "open network succeeds" "$status" "0"
check "open network without key" "$(conf | grep -c 'key_mgmt=NONE')" "1"
rm -rf "$tree"

# A hidden network with odd characters in its name.
setup
run 'geheim123\n' --ssid 'Wohnung "2"'
check "odd name stored as hex" "$(conf | grep -c "ssid=$(hex 'Wohnung "2"')$")" "1"
check "hidden network: no scan" "$(grep -c ' scan$' "$tree/calls.log")" "0"
rm -rf "$tree"

# A password WPA does not allow changes nothing.
setup
run '1\nkurz\n'
check "short password refused" "$status" "1"
check "short password: no network stored" "$(conf | grep -c '^network={')" "0"
check "short password: no reconfigure" "$(grep -c reconfigure "$tree/calls.log")" "0"
rm -rf "$tree"

# No address in time: an error that says what to try.
setup
: > "$tree/no-address"
run '1\ngeheim123\n'
check "no address fails" "$status" "1"
check "no address: hint" "$(grep -c 'keine Adresse' "$tree/out.log")" "1"
rm -rf "$tree"

# Nothing in range.
setup
head -n 1 "$tree/scan.txt" > "$tree/scan.new" && mv "$tree/scan.new" "$tree/scan.txt"
run ''
check "no network found" "$(grep -c 'kein Netz gefunden' "$tree/out.log")" "1"
rm -rf "$tree"

# Another country replaces the old one; a wrong one is refused.
setup
run '1\ngeheim123\n'
run '1\ngeheim123\n' --country AT
check "country changed" "$(conf | grep '^country=')" "country=AT"
run '' --country de
check "lowercase country refused" "$(grep -c 'zwei Großbuchstaben' "$tree/out.log")" "1"
rm -rf "$tree"

# --off switches wpa_supplicant off and keeps the networks.
setup
run '1\ngeheim123\n'
run '' --off
check "off succeeds" "$status" "0"
check "off disables wpa_supplicant" "$(grep -c '^systemctl disable --now wpa_supplicant@wlan0.service$' "$tree/calls.log")" "1"
check "off keeps the networks" "$(conf | grep -c '^network={')" "1"
rm -rf "$tree"

# The control socket comes a moment after the start; the scan waits for it.
setup
echo 2 > "$tree/ping-late"
run '1\ngeheim123\n'
check "late control socket: connect succeeds" "$status" "0"
check "late control socket: scanned after it" "$(grep -c ' scan$' "$tree/calls.log")" "1"
rm -rf "$tree"

# A wpa_supplicant that never answers is named, not a bare wpa_cli error.
setup
echo 99 > "$tree/ping-late"
run '1\ngeheim123\n'
check "no control socket fails" "$status" "1"
check "no control socket: message" "$(grep -c 'wpa_supplicant antwortet nicht' "$tree/out.log")" "1"
check "no control socket: no scan" "$(grep -c ' scan$' "$tree/calls.log")" "0"
rm -rf "$tree"

# --on brings WLAN back with the stored networks, without asking.
setup
run '' --on
check "--on without a network fails" "$(grep -c 'noch kein Netz eingerichtet' "$tree/out.log")" "1"
run '1\ngeheim123\n'
run '' --off
rm -f "$tree/connected"
: > "$tree/calls.log"
run '' --on
check "--on succeeds" "$status" "0"
check "--on starts wpa_supplicant" "$(grep -c '^systemctl enable --now wpa_supplicant@wlan0.service$' "$tree/calls.log")" "1"
check "--on unblocks WLAN" "$(grep -c '^rfkill unblock wifi$' "$tree/calls.log")" "1"
check "--on does not scan" "$(grep -c ' scan$' "$tree/calls.log")" "0"
check "--on does not ask" "$(grep -c 'Passwort' "$tree/out.log")" "0"
check "--on shows the address" "$(grep -c 'Verbunden, Adresse 192.168.2.77' "$tree/out.log")" "1"
check "--on keeps the network" "$(conf | grep -c '^network={')" "1"
run '' --off
rm -f "$tree/connected"
: > "$tree/no-address"
run '' --on
check "--on without address fails" "$status" "1"
check "--on without address: hint" "$(grep -c 'gespeicherten Netze in Reichweite' "$tree/out.log")" "1"
rm -rf "$tree"

# Without a WLAN interface.
setup
rmdir "$tree/net/wlan0"
run ''
check "no WLAN device" "$(grep -c 'kein WLAN-Gerät' "$tree/out.log")" "1"
rm -rf "$tree"

if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "all carnine-wlan tests passed"
