#!/bin/sh
# Tests for deploy_maps.sh with stand-ins for ssh and rsync, which log what
# they would do; no device needed.

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/deploy_maps.sh"
failures=0

# Source folders for Hessen and DACH with small files and their SHA256SUMS.
setup() {
    tree=$(mktemp -d)
    maps="$tree/carnine-maps"
    mkdir -p "$maps/germany" "$maps/dach"
    for file in hessen.mbtiles GPS-Adnan-Tour.txt valhalla_tiles.tar germany/hessen_names.db \
        germany_names.db dach/dach.mbtiles dach/dach_names.db dach/valhalla_tiles.tar; do
        printf '%s\n' "$file" > "$maps/$file"
    done
    (cd "$maps" && sha256sum hessen.mbtiles GPS-Adnan-Tour.txt valhalla_tiles.tar germany_names.db > SHA256SUMS)
    (cd "$maps/germany" && sha256sum hessen_names.db > SHA256SUMS)
    (cd "$maps/dach" && sha256sum dach.mbtiles dach_names.db valhalla_tiles.tar > SHA256SUMS)
    # The fake ssh answers the space query with FAKE_FREE and four old
    # sizes of 0, and logs every other command with what it gets on stdin.
    cat > "$tree/fake-ssh" <<EOF
#!/bin/sh
case "\$2" in
    df*) echo "\${FAKE_FREE:-100000000}"; echo 0; echo 0; echo 0; echo 0; exit 0 ;;
esac
echo "ssh \$*" >> "$tree/ssh.log"
if [ "\$2" = bash ]; then cat >> "$tree/ssh.log"; fi
EOF
    # $5 and $last belong to the generated script, not to this one.
    # shellcheck disable=SC2016
    printf '#!/bin/sh\nfor last; do :; done\necho "rsync $(basename "$5") $last" >> "%s/rsync.log"\n' "$tree" > "$tree/fake-rsync"
    chmod +x "$tree/fake-ssh" "$tree/fake-rsync"
    : > "$tree/ssh.log"
    : > "$tree/rsync.log"
}

run() {
    status=0
    CARNINE_MAPS_DIR="$maps" CARNINE_SSH="$tree/fake-ssh" CARNINE_RSYNC="$tree/fake-rsync" \
        bash "$SCRIPT" "$@" > "$tree/out.log" 2>&1 || status=$?
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

# Hessen is the default, with the names database that belongs to its tiles.
setup
run pi@device
check "Hessen deploys" "$status" "0"
check "Hessen copies" "$(cat "$tree/rsync.log")" "$(printf '%s\n' \
    "rsync hessen.mbtiles pi@device:/var/lib/carnine/maps/map.mbtiles" \
    "rsync hessen_names.db pi@device:/var/lib/carnine/maps/germany_names.db" \
    "rsync GPS-Adnan-Tour.txt pi@device:/var/lib/carnine/maps/GPS-Adnan-Tour.txt" \
    "rsync valhalla_tiles.tar pi@device:/var/lib/valhalla/valhalla_tiles.tar")"
check "Hessen sets map_region" "$(grep -c '^ssh pi@device bash -s -- 1 Hessen$' "$tree/ssh.log")" "1"
check "services stopped before the copy" "$(grep -c 'systemctl stop' "$tree/ssh.log")" "1"
check "Hessen checksums checked" "$(grep -c 'checking' "$tree/out.log")" "4"
rm -rf "$tree"

# --dach takes everything but the tour from the DACH folder.
setup
run pi@device --dach
check "DACH deploys" "$status" "0"
check "DACH copies" "$(cat "$tree/rsync.log")" "$(printf '%s\n' \
    "rsync dach.mbtiles pi@device:/var/lib/carnine/maps/map.mbtiles" \
    "rsync dach_names.db pi@device:/var/lib/carnine/maps/germany_names.db" \
    "rsync GPS-Adnan-Tour.txt pi@device:/var/lib/carnine/maps/GPS-Adnan-Tour.txt" \
    "rsync valhalla_tiles.tar pi@device:/var/lib/valhalla/valhalla_tiles.tar")"
check "DACH routing tiles from the DACH folder" "$(grep -c 'dach/valhalla_tiles.tar, checking' "$tree/out.log")" "1"
check "DACH sets map_region" "$(grep -c '^ssh pi@device bash -s -- 1 DACH$' "$tree/ssh.log")" "1"
rm -rf "$tree"

# A file that does not match its SHA256SUMS stops everything before the device.
setup
printf 'changed\n' >> "$maps/dach/dach.mbtiles"
run pi@device --dach
check "bad checksum fails" "$status" "1"
check "bad checksum: nothing copied" "$(cat "$tree/rsync.log")" ""
check "bad checksum: device untouched" "$(cat "$tree/ssh.log")" ""
rm -rf "$tree"

# Too little room on the device: no service is stopped, nothing copied.
setup
FAKE_FREE=10 run pi@device
check "too little room fails" "$status" "1"
check "too little room: message" "$(grep -c 'GB free' "$tree/out.log")" "1"
check "too little room: services untouched" "$(cat "$tree/ssh.log")" ""
check "too little room: nothing copied" "$(cat "$tree/rsync.log")" ""
rm -rf "$tree"

# A missing file is named.
setup
rm "$maps/dach/dach_names.db"
run pi@device --dach
check "missing file fails" "$(grep -c 'not found: .*dach_names.db' "$tree/out.log")" "1"
rm -rf "$tree"

# --no-restart leaves the services alone.
setup
run pi@device --no-restart
check "--no-restart deploys" "$status" "0"
check "--no-restart: no stop" "$(grep -c 'systemctl stop' "$tree/ssh.log")" "0"
check "--no-restart passed on" "$(grep -c '^ssh pi@device bash -s -- 0 Hessen$' "$tree/ssh.log")" "1"
rm -rf "$tree"

if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "all deploy_maps tests passed"
