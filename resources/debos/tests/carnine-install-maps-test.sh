#!/bin/sh
# Tests for carnine-install-maps.sh on a scratch tree, with a package folder
# instead of the share (curl reads it through file://); no root needed.

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/carnine-install-maps.sh"
failures=0
NAMES="map.mbtiles germany_names.db GPS-Adnan-Tour.txt valhalla_tiles.tar"

# A package with small stand-ins for the four files; $1 is mixed into their
# content so that two packages differ.
make_package() {
    package="$tree/package-$1"
    mkdir -p "$package"
    : > "$package/SHA256SUMS.entpackt"
    printf '# datei\tgepackt\tentpackt\n' > "$package/INHALT"
    for name in $NAMES; do
        head -c 20000 /dev/urandom > "$tree/$name.$1"
        printf '%s %s\n' "$1" "$name" >> "$tree/$name.$1"
        zstd -q -f "$tree/$name.$1" -o "$package/$name.zst"
        (cd "$tree" && sha256sum "$name.$1" | sed "s/\.$1\$//") >> "$package/SHA256SUMS.entpackt"
        printf '%s.zst\t%s\t%s\n' "$name" "$(stat -c %s "$package/$name.zst")" \
            "$(stat -c %s "$tree/$name.$1")" >> "$package/INHALT"
    done
    (cd "$package" && sha256sum ./*.zst | sed 's#  \./#  #' > SHA256SUMS)
}

setup() {
    tree=$(mktemp -d)
    mkdir -p "$tree/maps" "$tree/valhalla"
    : > "$tree/systemctl.log"
    : > "$tree/chown.log"
    printf '#!/bin/sh\necho "$*" >> "%s/systemctl.log"\n' "$tree" > "$tree/fake-systemctl"
    printf '#!/bin/sh\necho "$*" >> "%s/chown.log"\n' "$tree" > "$tree/fake-chown"
    chmod +x "$tree/fake-systemctl" "$tree/fake-chown"
    make_package a
}

# run <free bytes> <arguments...>; the exit code lands in $status.
run() {
    free=$1
    shift
    status=0
    CARNINE_MAPS_DIR="$tree/maps" CARNINE_VALHALLA_DIR="$tree/valhalla" \
        CARNINE_SYSTEMCTL="$tree/fake-systemctl" CARNINE_CHOWN="$tree/fake-chown" \
        CARNINE_FREE_BYTES="$free" CARNINE_MAPS_RESERVE=1000 CARNINE_SKIP_ROOT_CHECK=1 \
        sh "$SCRIPT" "$@" > "$tree/out.log" 2>&1 || status=$?
}

installed() {
    for name in $NAMES; do
        case "$name" in
            valhalla_tiles.tar) target="$tree/valhalla/$name" ;;
            *) target="$tree/maps/$name" ;;
        esac
        cmp -s "$target" "$tree/$name.$1" || { echo "no: $name"; return; }
    done
    echo yes
}

# count <pattern> <dir>...: files in the folders whose name matches.
count() {
    pattern=$1
    shift
    find "$@" -maxdepth 1 -name "$pattern" | wc -l | tr -d ' '
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

# Share links become the public WebDAV address with the token as user.
tree=$(mktemp -d)
show() {
    CARNINE_SKIP_ROOT_CHECK=1 sh "$SCRIPT" --show-source "$@" 2>&1 || true
}
check "MagentaCloud link" "$(show --link https://magentacloud.de/s/AbCdEf0123456789)" \
    "https://magentacloud.de/public.php/webdav/karten-hessen AbCdEf0123456789"
check "link with index.php, path and slash" \
    "$(show --link https://example.org/cloud/index.php/s/AbC123/ --package karten-dach)" \
    "https://example.org/cloud/public.php/webdav/karten-dach AbC123"
check "not a share link" "$(show --link https://example.org/files/x | grep -c FEHLER)" "1"
rm -rf "$tree"

# A fresh device: everything is installed, services stopped and started again.
setup
printf 'old' > "$tree/maps/germany_names.db-wal"
printf 'old' > "$tree/maps/germany_names.db-shm"
run 100000000 --dir "$tree/package-a"
check "fresh install succeeds" "$status" "0"
check "all four files installed" "$(installed a)" "yes"
check "services stopped, then started" "$(cat "$tree/systemctl.log")" \
    "$(printf 'stop carnine-frontend.service carnine-backend.service valhalla.service\nstart carnine-frontend.service carnine-backend.service valhalla.service')"
check "valhalla tiles belong to root" "$(grep -c "^root:root $tree/valhalla/valhalla_tiles.tar.new" "$tree/chown.log")" "1"
check "map files belong to carnine" "$(grep -c "^carnine:carnine $tree/maps/" "$tree/chown.log")" "3"
check "valhalla tiles world-readable" "$(stat -c %a "$tree/valhalla/valhalla_tiles.tar")" "644"
check "map files not world-readable" "$(stat -c %a "$tree/maps/map.mbtiles")" "640"
check "old -wal/-shm removed" "$(($(count '*-wal' "$tree/maps") + $(count '*-shm' "$tree/maps")))" "0"
check "download folder cleaned up" "$(test -e "$tree/maps/.download" && echo left || echo gone)" "gone"

# A second run with the same package changes nothing and keeps the services up.
: > "$tree/systemctl.log"
run 100000000 --dir "$tree/package-a"
check "second run succeeds" "$status" "0"
check "second run: nothing to do" "$(grep -c 'nichts zu tun' "$tree/out.log")" "1"
check "second run: services untouched" "$(cat "$tree/systemctl.log")" ""

# A newer package replaces the files.
make_package b
run 100000000 --dir "$tree/package-b"
check "newer package installed" "$(installed b)" "yes"
rm -rf "$tree"

# Too little room: nothing is downloaded, nothing stopped.
setup
run 1000 --dir "$tree/package-a"
check "too little room fails" "$status" "2"
check "too little room: message" "$(grep -c 'zu wenig Platz' "$tree/out.log")" "1"
check "too little room: services untouched" "$(cat "$tree/systemctl.log")" ""
check "too little room: nothing installed" "$(($(count map.mbtiles "$tree/maps") + $(count valhalla_tiles.tar "$tree/valhalla")))" "0"
rm -rf "$tree"

# An aborted download continues from where it stopped.
setup
mkdir -p "$tree/maps/.download"
head -c 5000 "$tree/package-a/valhalla_tiles.tar.zst" > "$tree/maps/.download/valhalla_tiles.tar.zst.part"
run 100000000 --dir "$tree/package-a"
check "resumed download installs" "$(installed a)" "yes"
rm -rf "$tree"

# A broken download is thrown away before any service is stopped.
setup
printf 'x' >> "$tree/package-a/map.mbtiles.zst"
run 100000000 --dir "$tree/package-a"
check "bad checksum fails" "$status" "3"
check "bad checksum: services untouched" "$(cat "$tree/systemctl.log")" ""
check "bad checksum: broken file deleted" "$(count 'map.mbtiles*' "$tree/maps/.download")" "0"
rm -rf "$tree"

# A file that unpacks wrong keeps the old one, and the services come back.
setup
run 100000000 --dir "$tree/package-a"
make_package b
sed -i 's/^[0-9a-f]*  GPS-Adnan-Tour.txt$/0000000000000000000000000000000000000000000000000000000000000000  GPS-Adnan-Tour.txt/' \
    "$tree/package-b/SHA256SUMS.entpackt"
: > "$tree/systemctl.log"
run 100000000 --dir "$tree/package-b"
check "bad unpacked file fails" "$status" "3"
check "bad unpacked file: old one kept" "$(cmp -s "$tree/maps/GPS-Adnan-Tour.txt" "$tree/GPS-Adnan-Tour.txt.a" && echo kept)" "kept"
check "bad unpacked file: services back up" "$(tail -n 1 "$tree/systemctl.log")" \
    "start carnine-frontend.service carnine-backend.service valhalla.service"
check "bad unpacked file: no leftover .new" "$(count '*.new' "$tree/maps")" "0"
rm -rf "$tree"

# Round trip: a package made by pack_maps.sh installs the very files it
# was made from.
setup
mkdir -p "$tree/sources"
for name in $NAMES; do
    cp "$tree/$name.a" "$tree/sources/$name"
done
pack_status=0
CARNINE_MAPS_DIR="$tree/sources" CARNINE_MAP_TILES="$tree/sources/map.mbtiles" \
    CARNINE_NAMES_DATABASE="$tree/sources/germany_names.db" \
    bash "$(dirname "$SCRIPT")/../../pack_maps.sh" "$tree/karten-test" > "$tree/out.log" 2>&1 || pack_status=$?
check "pack_maps.sh succeeds" "$pack_status" "0"
check "pack_maps.sh leaves no .tmp" "$(test -e "$tree/karten-test.tmp" && echo left || echo gone)" "gone"
check "pack_maps.sh writes LIESMICH" "$(grep -c 'carnine-install-maps' "$tree/karten-test/LIESMICH.txt")" "1"
run 100000000 --dir "$tree/karten-test"
check "packed package installs" "$status" "0"
check "packed package: same files" "$(installed a)" "yes"
rm -rf "$tree"

# A failed download says why: TLS and network errors are not blamed on the
# link, only an HTTP error is.
setup
for code in 77 60 6 7 22; do
    printf '#!/bin/sh\nexit %s\n' "$code" > "$tree/fake-curl"
    chmod +x "$tree/fake-curl"
    export CARNINE_CURL="$tree/fake-curl"
    run 100000000 --link https://example.org/s/AbC123
    unset CARNINE_CURL
    case "$code" in
        77|60) expected="HTTPS-Verbindung fehlgeschlagen (curl-Fehler $code)" ;;
        6) expected="Server nicht gefunden (curl-Fehler 6)" ;;
        7) expected="keine Verbindung zum Server (curl-Fehler 7)" ;;
        22) expected="konnte INHALT nicht laden (curl-Fehler 22, Link oder Paketname falsch?)" ;;
    esac
    check "curl error $code explained" "$(grep -cF "$expected" "$tree/out.log")" "1"
    check "curl error $code: services untouched" "$(cat "$tree/systemctl.log")" ""
done
rm -rf "$tree"

# A package with a file the script does not know is refused.
setup
printf 'unbekannt.zst\t10\t10\n' >> "$tree/package-a/INHALT"
run 100000000 --dir "$tree/package-a"
check "unknown file refused" "$(grep -c 'unbekannte Datei' "$tree/out.log")" "1"
check "unknown file: services untouched" "$(cat "$tree/systemctl.log")" ""
rm -rf "$tree"

if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "all carnine-install-maps tests passed"
