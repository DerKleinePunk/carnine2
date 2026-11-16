#!/bin/sh
# Installs a map package (tiles, names, demo tour, Valhalla routing tiles) on
# the device itself, so that a tester needs neither the repository nor
# deploy_maps.sh. Installed as /usr/local/sbin/carnine-install-maps.
#
#   sudo carnine-install-maps                      asks for the share link
#   sudo carnine-install-maps --link <share-link>  a Nextcloud share link
#   sudo carnine-install-maps --dir <folder>       a package folder, e.g. on a USB stick
#   sudo carnine-install-maps --package routing-de ...   routing tiles of one country
#   sudo carnine-install-maps --remove-routing de        takes a country out again
#   carnine-install-maps --list-routing                  the countries installed
#
# A package is a folder (default name karten-hessen) holding <file>.zst for
# each file, INHALT (packed and unpacked sizes), SHA256SUMS (of the .zst) and
# SHA256SUMS.entpackt (of the unpacked files). The share link is not built
# in: whoever hands out the package hands out the link.
#
# A country routing package (routing-<land>, made by
# resources/tools/valhalla-pakete/routing_paket.py) holds routing-<land>.info
# (country, build, Valhalla version) and routing-<land>.tar with the Valhalla
# tiles that touch the country. Its tiles go loose into Valhalla's tile_dir,
# next to those of the other countries, and Valhalla routes across the border
# - as long as all countries come from the same build, which is checked. A
# whole-area valhalla_tiles.tar would win over the loose tiles, so it is put
# aside and comes back when the last country is removed. Only Valhalla
# restarts for a country.
#
# Downloads resume: running it again after an abort continues where it
# stopped. Free space is checked before anything is downloaded. The services
# are only stopped once every file is downloaded and verified, and come back
# up even if unpacking fails. A file installed by an earlier run with the same
# checksum is skipped.
#
# The paths and commands can be overridden so the tests can run it on a
# scratch tree.

set -eu

MAPS_DIR=${CARNINE_MAPS_DIR:-/var/lib/carnine/maps}
VALHALLA_DIR=${CARNINE_VALHALLA_DIR:-/var/lib/valhalla}
WORK_DIR=${CARNINE_MAPS_WORK_DIR:-$MAPS_DIR/.download}
STAMP="$MAPS_DIR/.installed"
SYSTEMCTL=${CARNINE_SYSTEMCTL:-systemctl}
CHOWN=${CARNINE_CHOWN:-chown}
CURL=${CARNINE_CURL:-curl}
# Room left over after the installation, for the database and logs.
RESERVE=${CARNINE_MAPS_RESERVE:-268435456}
SERVICES="carnine-frontend.service carnine-backend.service valhalla.service"
# Country routing packages: tile_dir of resources/valhalla/valhalla.json, and
# the info and tile list of every country installed.
TILE_DIR=${CARNINE_VALHALLA_TILE_DIR:-$VALHALLA_DIR/valhalla_tiles}
ROUTING_DIR="$VALHALLA_DIR/pakete"
FULL_TAR="$VALHALLA_DIR/valhalla_tiles.tar"
FULL_TAR_ASIDE="$FULL_TAR.vor-laenderpaketen"

PACKAGE=karten-hessen
LINK=""
SOURCE_DIR=""
SHOW_SOURCE=0
REMOVE_ROUTING=""
LIST_ROUTING=0

usage() {
    echo "Aufruf: sudo carnine-install-maps [--link <freigabe-link>] [--dir <ordner>] [--package <name>]" >&2
    echo "        sudo carnine-install-maps --remove-routing <land>" >&2
    echo "        carnine-install-maps --list-routing" >&2
    exit 1
}

die() {
    echo "FEHLER: $*" >&2
    exit "${EXIT_CODE:-1}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --link) [ $# -ge 2 ] || usage; LINK=$2; shift 2 ;;
        --dir) [ $# -ge 2 ] || usage; SOURCE_DIR=$2; shift 2 ;;
        --package) [ $# -ge 2 ] || usage; PACKAGE=$2; shift 2 ;;
        --show-source) SHOW_SOURCE=1; shift ;;
        --remove-routing) [ $# -ge 2 ] || usage; REMOVE_ROUTING=$2; shift 2 ;;
        --list-routing) LIST_ROUTING=1; shift ;;
        *) usage ;;
    esac
done

# info_value <info file> <key>: one key=value line of a routing-<land>.info.
info_value() {
    sed -n "s/^$2=//p" "$1" | head -n 1
}

# The tile list of the countries other than $1 (routing-<land>), sorted.
other_tiles() {
    for list in "$ROUTING_DIR"/routing-*.kacheln; do
        [ -e "$list" ] || continue
        [ "$list" = "$ROUTING_DIR/$1.kacheln" ] || cat "$list"
    done | sort -u
}

# remove_tiles <routing-land>: deletes the tiles of that country that no other
# country needs (the border tiles stay), then its tile list. The info stays.
remove_tiles() {
    list="$ROUTING_DIR/$1.kacheln"
    if [ -e "$list" ]; then
        other_tiles "$1" > "$ROUTING_DIR/.andere"
        sort -u "$list" | comm -23 - "$ROUTING_DIR/.andere" | while IFS= read -r tile; do
            case "$tile" in
                ''|/*|*..*) continue ;;
            esac
            rm -f "$TILE_DIR/$tile"
        done
        rm -f "$ROUTING_DIR/.andere"
        [ -d "$TILE_DIR" ] && find "$TILE_DIR" -mindepth 1 -type d -empty -delete
    fi
    rm -f "$list"
}

routing_countries() {
    for info in "$ROUTING_DIR"/routing-*.info; do
        [ -e "$info" ] && echo "$info"
    done
}

if [ "$LIST_ROUTING" -eq 1 ]; then
    if [ -z "$(routing_countries)" ]; then
        echo "Keine Länderpakete fürs Routing installiert."
        exit 0
    fi
    for info in $(routing_countries); do
        name=$(basename "$info" .info)
        printf '%s: Bau %s, Valhalla %s, %s Kacheln\n' "${name#routing-}" \
            "$(info_value "$info" bau)" "$(info_value "$info" valhalla)" \
            "$(wc -l < "$ROUTING_DIR/$name.kacheln" 2>/dev/null || echo 0)"
    done
    [ -e "$FULL_TAR" ] && echo "Hinweis: $FULL_TAR ist da und gewinnt vor den Länderpaketen."
    exit 0
fi

if [ "$(id -u)" -ne 0 ] && [ -z "${CARNINE_SKIP_ROOT_CHECK:-}" ] && [ "$SHOW_SOURCE" -eq 0 ]; then
    die "bitte mit sudo aufrufen: sudo carnine-install-maps"
fi

if [ -n "$REMOVE_ROUTING" ]; then
    name="routing-${REMOVE_ROUTING#routing-}"
    case "${name#routing-}" in
        ''|*[!a-z0-9]*) die "Ländername nur aus Kleinbuchstaben und Ziffern, z. B. de" ;;
    esac
    [ -e "$ROUTING_DIR/$name.info" ] ||
        die "kein Länderpaket $name installiert (siehe carnine-install-maps --list-routing)"
    "$SYSTEMCTL" stop valhalla.service
    trap '"$SYSTEMCTL" start valhalla.service || true' EXIT
    remove_tiles "$name"
    rm -f "$ROUTING_DIR/$name.info"
    if [ -z "$(routing_countries)" ]; then
        # The last country: its folders go too, if nothing else is in them.
        rmdir "$TILE_DIR" 2>/dev/null || true
        rmdir "$ROUTING_DIR" 2>/dev/null || true
        if [ -e "$FULL_TAR_ASIDE" ] && [ ! -e "$FULL_TAR" ]; then
            mv "$FULL_TAR_ASIDE" "$FULL_TAR"
            echo "Letztes Land entfernt: das ganze Routing-Paket ($FULL_TAR) gilt wieder."
        fi
    fi
    echo "Fertig: $name entfernt. Valhalla startet neu."
    exit 0
fi

# A country routing package only touches Valhalla.
ROUTING=0
case "$PACKAGE" in
    routing-*)
        case "${PACKAGE#routing-}" in
            ''|*[!a-z0-9]*) die "Ländername nur aus Kleinbuchstaben und Ziffern, z. B. routing-de" ;;
        esac
        ROUTING=1
        SERVICES="valhalla.service"
        ;;
esac

if [ -z "$LINK" ] && [ -z "$SOURCE_DIR" ]; then
    printf 'Freigabe-Link für die Kartendaten (z. B. https://magentacloud.de/s/...): ' >&2
    read -r LINK < /dev/tty || die "kein Link eingegeben"
    [ -n "$LINK" ] || die "kein Link eingegeben"
fi

# A Nextcloud share link https://host[/path][/index.php]/s/<token> is read
# through the share's public WebDAV interface, with the token as user name
# and an empty password.
AUTH_USER=""
if [ -n "$SOURCE_DIR" ]; then
    [ -d "$SOURCE_DIR" ] || die "Ordner nicht gefunden: $SOURCE_DIR"
    BASE="file://$(cd "$SOURCE_DIR" && pwd)"
else
    AUTH_USER=$(printf '%s' "$LINK" | sed -nE 's#^https?://.+/s/([A-Za-z0-9]+)/?([?\#].*)?$#\1#p')
    [ -n "$AUTH_USER" ] || die "das ist kein Freigabe-Link der Form https://<server>/s/<kennung>: $LINK"
    root=$(printf '%s' "$LINK" | sed -E 's#/s/[A-Za-z0-9]+/?([?\#].*)?$##; s#/index\.php$##')
    BASE="$root/public.php/webdav/$PACKAGE"
fi

if [ "$SHOW_SOURCE" -eq 1 ]; then
    printf '%s %s\n' "$BASE" "$AUTH_USER"
    exit 0
fi

# fetch <file> <output> [progress]: --continue-at resumes a partial output.
fetch() {
    if [ -n "$AUTH_USER" ]; then
        set -- "$@" -u "$AUTH_USER:" -H "X-Requested-With: XMLHttpRequest"
    fi
    file=$1 output=$2 progress=$3
    shift 3
    if [ "$progress" = progress ]; then
        "$CURL" -fL --retry 3 -C - -o "$output" "$@" "$BASE/$file"
    else
        "$CURL" -fsSL --retry 3 -o "$output" "$@" "$BASE/$file"
    fi
}

# fetch_failure <curl exit code> <file>: what went wrong, in words a tester
# can act on; only an HTTP error points at the link itself.
fetch_failure() {
    case "$1" in
        35|58|59|60|77|83)
            echo "HTTPS-Verbindung fehlgeschlagen (curl-Fehler $1): Zertifikate fehlen (Paket ca-certificates) oder die Uhrzeit des Geräts stimmt nicht" ;;
        6)
            echo "Server nicht gefunden (curl-Fehler 6): keine Internetverbindung oder Name im Link falsch" ;;
        7|28)
            echo "keine Verbindung zum Server (curl-Fehler $1): Internetverbindung prüfen" ;;
        *)
            echo "konnte $2 nicht laden (curl-Fehler $1, Link oder Paketname falsch?)" ;;
    esac
}

target_of() {
    # A country routing package holds its info and its tiles, nothing else.
    if [ "$ROUTING" -eq 1 ]; then
        case "$1" in
            "$PACKAGE.info"|"$PACKAGE.tar") echo "$ROUTING_DIR/$1" ;;
            *) return 1 ;;
        esac
        return 0
    fi
    case "$1" in
        map.mbtiles|germany_names.db|GPS-Adnan-Tour.txt) echo "$MAPS_DIR/$1" ;;
        valhalla_tiles.tar) echo "$VALHALLA_DIR/$1" ;;
        *) return 1 ;;
    esac
}

# is_current <target> <sum> <unpacked size>: installed by an earlier run. The
# tar of a routing package is unpacked and deleted, its tile list stays.
is_current() {
    grep -qx "$2 $3 $1" "$STAMP" 2>/dev/null || return 1
    case "$1" in
        "$ROUTING_DIR"/*.tar) [ -e "${1%.tar}.kacheln" ] ;;
        *) [ -e "$1" ] && [ "$(size_of "$1")" = "$3" ] ;;
    esac
}

size_of() {
    if [ -e "$1" ]; then stat -c %s "$1"; else echo 0; fi
}

sum_of() {
    awk -v name="$2" '$2 == name || $2 == "*" name { print $1 }' "$1"
}

gb() {
    awk -v bytes="$1" 'BEGIN { printf "%.1f GB", bytes / 1000000000 }' | tr . ,
}

mkdir -p "$WORK_DIR" "$MAPS_DIR" "$VALHALLA_DIR"
[ "$ROUTING" -eq 1 ] && mkdir -p "$ROUTING_DIR" "$TILE_DIR"
echo "Hole die Paketliste von $BASE ..."
for list in INHALT SHA256SUMS SHA256SUMS.entpackt; do
    rc=0
    fetch "$list" "$WORK_DIR/$list" quiet || rc=$?
    [ "$rc" -eq 0 ] || die "$(fetch_failure "$rc" "$list")"
done

# Work out what is still to do and how much room that needs at most: the
# rest of every download, the largest unpacked file while it is written next
# to its predecessor, and whatever the new files are larger than the old.
TODO_LIST="$WORK_DIR/todo"
: > "$TODO_LIST"
download=0 largest=0 growth=0
while IFS="$(printf '\t')" read -r packed packed_size unpacked_size; do
    case "$packed" in ''|'#'*) continue ;; esac
    name=${packed%.zst}
    target=$(target_of "$name") || die "unbekannte Datei im Paket: $packed"
    sum=$(sum_of "$WORK_DIR/SHA256SUMS.entpackt" "$name")
    [ -n "$sum" ] || die "keine Prüfsumme für $name in SHA256SUMS.entpackt"
    if is_current "$target" "$sum" "$unpacked_size"; then
        echo "  $name ist schon aktuell"
        continue
    fi
    printf '%s\t%s\t%s\t%s\n' "$packed" "$packed_size" "$unpacked_size" "$target" >> "$TODO_LIST"
    partial=$(size_of "$WORK_DIR/$packed.part")
    [ -e "$WORK_DIR/$packed" ] && partial=$packed_size
    download=$((download + packed_size - partial))
    [ "$unpacked_size" -gt "$largest" ] && largest=$unpacked_size
    old=$(size_of "$target")
    [ "$unpacked_size" -gt "$old" ] && growth=$((growth + unpacked_size - old))
done < "$WORK_DIR/INHALT"

if [ ! -s "$TODO_LIST" ]; then
    rm -rf "$WORK_DIR"
    echo "Die Kartendaten sind schon installiert, nichts zu tun."
    exit 0
fi

needed=$((download + largest + growth + RESERVE))
free=${CARNINE_FREE_BYTES:-$(df -B1 --output=avail "$MAPS_DIR" | tail -n 1 | tr -d ' ')}
if [ "$free" -lt "$needed" ]; then
    EXIT_CODE=2 die "zu wenig Platz: nötig sind $(gb "$needed"), frei sind $(gb "$free"). Größere SD-Karte nehmen oder Platz schaffen."
fi

echo "Herunterzuladen: $(gb "$download"). Ein Abbruch schadet nicht: derselbe Aufruf macht weiter."
while IFS="$(printf '\t')" read -r packed packed_size unpacked_size target; do
    if [ ! -e "$WORK_DIR/$packed" ]; then
        if [ "$(size_of "$WORK_DIR/$packed.part")" -gt "$packed_size" ]; then
            rm -f "$WORK_DIR/$packed.part"
        fi
        if [ "$(size_of "$WORK_DIR/$packed.part")" -lt "$packed_size" ]; then
            echo "Lade $packed ($(gb "$packed_size")) ..."
            fetch "$packed" "$WORK_DIR/$packed.part" progress < /dev/null ||
                die "Herunterladen von $packed abgebrochen. Derselbe Aufruf macht weiter."
        fi
        sum=$(sha256sum "$WORK_DIR/$packed.part" | cut -d ' ' -f 1)
        if [ "$sum" != "$(sum_of "$WORK_DIR/SHA256SUMS" "$packed")" ]; then
            rm -f "$WORK_DIR/$packed.part"
            EXIT_CODE=3 die "Prüfsumme von $packed falsch, die Datei ist gelöscht. Bitte noch einmal aufrufen."
        fi
        mv "$WORK_DIR/$packed.part" "$WORK_DIR/$packed"
    fi
done < "$TODO_LIST"

# A country fits only to countries of the same build: their border tiles are
# the same then. Checked before anything is touched.
if [ "$ROUTING" -eq 1 ]; then
    if [ -e "$WORK_DIR/$PACKAGE.info.zst" ]; then
        zstd -q -d -c "$WORK_DIR/$PACKAGE.info.zst" > "$WORK_DIR/new.info"
    elif [ -e "$ROUTING_DIR/$PACKAGE.info" ]; then
        cp "$ROUTING_DIR/$PACKAGE.info" "$WORK_DIR/new.info"
    else
        die "$PACKAGE hat keine $PACKAGE.info"
    fi
    build=$(info_value "$WORK_DIR/new.info" bau)
    [ -n "$build" ] || die "$PACKAGE.info nennt keinen Bau"
    for info in $(routing_countries); do
        [ "$info" = "$ROUTING_DIR/$PACKAGE.info" ] && continue
        other=$(info_value "$info" bau)
        if [ "$other" != "$build" ]; then
            EXIT_CODE=4 die "$PACKAGE stammt aus dem Bau $build, $(basename "$info" .info) aus $other. Länder aus verschiedenen Bauten passen an der Grenze nicht zusammen. Erst entfernen: sudo carnine-install-maps --remove-routing $(basename "$info" .info | sed 's/^routing-//')"
        fi
    done
    if [ -e "$FULL_TAR" ] && [ -e "$FULL_TAR_ASIDE" ]; then
        die "$FULL_TAR und $FULL_TAR_ASIDE sind beide da; eins davon bitte von Hand wegräumen"
    fi
fi

# Everything is here and verified: only now stop the services, which read
# the files while they are replaced. They come back up however this ends.
stopped=0
restart() {
    if [ "$stopped" -eq 1 ]; then
        # shellcheck disable=SC2086
        "$SYSTEMCTL" start $SERVICES || true
    fi
}
trap restart EXIT
# shellcheck disable=SC2086
"$SYSTEMCTL" stop $SERVICES
stopped=1

while IFS="$(printf '\t')" read -r packed packed_size unpacked_size target; do
    name=${packed%.zst}
    echo "Entpacke $name ..."
    sum=$(zstd -q -d -c "$WORK_DIR/$packed" | tee "$target.new" | sha256sum | cut -d ' ' -f 1)
    if [ "$sum" != "$(sum_of "$WORK_DIR/SHA256SUMS.entpackt" "$name")" ] ||
        [ "$(size_of "$target.new")" != "$unpacked_size" ]; then
        rm -f "$target.new"
        EXIT_CODE=3 die "$name ist nach dem Entpacken nicht in Ordnung. Bitte noch einmal aufrufen."
    fi
    # The names database comes without WAL; a -wal/-shm left from the old
    # one makes SQLite call the new file malformed.
    rm -f "$target-wal" "$target-shm"
    # Backend and frontend run as carnine; Valhalla runs with a dynamic user
    # and so needs its tiles world-readable.
    case "$target" in
        "$VALHALLA_DIR"/*) "$CHOWN" root:root "$target.new"; chmod 0644 "$target.new" ;;
        *) "$CHOWN" carnine:carnine "$target.new"; chmod 0640 "$target.new" ;;
    esac
    case "$target" in
        "$ROUTING_DIR"/*.tar)
            # An update of the same country: its old tiles go first, except
            # those another country needs.
            remove_tiles "$PACKAGE"
            tar -t -f "$target.new" | grep '\.gph$' | sort > "${target%.tar}.kacheln.new"
            if [ ! -s "${target%.tar}.kacheln.new" ] ||
                grep -q -e '^/' -e '\.\.' "${target%.tar}.kacheln.new"; then
                rm -f "$target.new" "${target%.tar}.kacheln.new"
                EXIT_CODE=3 die "$name enthält keine Kacheln oder Pfade außerhalb des Kachelordners"
            fi
            (umask 022 && tar -x -f "$target.new" -C "$TILE_DIR" --no-same-owner --no-same-permissions)
            "$CHOWN" -R root:root "$TILE_DIR"
            mv "${target%.tar}.kacheln.new" "${target%.tar}.kacheln"
            rm -f "$target.new"
            # A whole-area tar wins over loose tiles; it comes back with
            # --remove-routing of the last country.
            if [ -e "$FULL_TAR" ]; then
                mv "$FULL_TAR" "$FULL_TAR_ASIDE"
                echo "Das ganze Routing-Paket liegt jetzt als $FULL_TAR_ASIDE beiseite."
            fi
            ;;
        *)
            mv "$target.new" "$target"
            if [ "$target" = "$FULL_TAR" ] && [ -n "$(routing_countries)" ]; then
                echo "Hinweis: $FULL_TAR gewinnt vor den Länderpaketen fürs Routing (carnine-install-maps --list-routing)."
            fi
            ;;
    esac
    rm -f "$WORK_DIR/$packed"
    { grep -v " $target\$" "$STAMP" 2>/dev/null || true; echo "$sum $unpacked_size $target"; } > "$STAMP.new"
    mv "$STAMP.new" "$STAMP"
done < "$TODO_LIST"

rm -rf "$WORK_DIR"
if [ "$ROUTING" -eq 1 ]; then
    echo "Fertig. Routing für ${PACKAGE#routing-} ist da, sobald Valhalla neu gestartet ist."
else
    echo "Fertig. Die Karte ist nach dem Neustart der Dienste in etwa einer Minute da."
fi
