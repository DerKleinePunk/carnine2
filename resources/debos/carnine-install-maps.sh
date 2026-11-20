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
# (country, build, Valhalla version), routing-<land>.poly (the country's
# border; the backend keeps routes inside the installed countries with it,
# packages from before 2026-11-20 have none) and routing-<land>.tar with the
# Valhalla tiles that touch the country. The countries together make up Valhalla's
# valhalla_tiles.tar, read the same way as a whole-area one (memory-mapped;
# loose tiles in tile_dir were slower on jeep-pi once warm, 2026-11-16): the
# whole-area tar is put aside and comes back when the last country goes. The
# tar is written anew with every country added or removed, with index.bin in
# front as valhalla_build_extract writes it, so Valhalla starts as fast as
# with a whole-area extract; the tiles are copied, nothing is unpacked.
# Valhalla routes across the border as long as all countries come from the
# same build, which is checked. Only Valhalla restarts for a country.
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
# The tile lists are sorted and compared with comm; the same order every run.
export LC_ALL=C

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
# Country routing packages: the info and tile list of every country
# installed; the tiles themselves are in valhalla_tiles.tar.
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

# The tile lists of the countries whose tiles are in valhalla_tiles.tar.
tile_lists() {
    for list in "$ROUTING_DIR"/routing-*.kacheln; do
        [ -e "$list" ] && echo "$list"
    done
}

# write_tar <output> <names to leave out of the last source> <source tar>...: a
# Valhalla tile extract, as valhalla_build_extract writes it: index.bin first
# (per tile its data offset, graph id and size, "<QLL"), then the tiles,
# sorted. Without the index Valhalla reads every tar header at start: 16 s
# instead of 1.5 s for DE+CH on jeep-pi (2026-11-16). The tiles are copied
# straight from the sources, nothing is unpacked; a name in more than one
# source is taken from the first. The last source is the old tar, so only
# there are tiles left out. The output is written next to it.
write_tar() {
    python3 - "$@" <<'PYTHON'
import io
import struct
import sys
import tarfile

out, leave_out, sources = sys.argv[1], sys.argv[2], sys.argv[3:]
skip = set()
if leave_out:
    with open(leave_out, encoding='utf-8') as f:
        skip = set(f.read().split())
tiles = {}
for n, source in enumerate(sources):
    left_out = skip if n == len(sources) - 1 else set()
    with tarfile.open(source) as tar:
        for member in tar.getmembers():
            name = member.name
            if member.isfile() and name.endswith('.gph') and name not in left_out \
                    and name not in tiles:
                tiles[name] = (source, member.offset_data, member.size)
if not tiles:
    sys.exit('no tiles left for ' + out)

entry = struct.Struct('<QLL')


def graph_id(name):
    level, tile = name[:-4].split('/', 1)
    return int(level) | (int(tile.replace('/', '')) << 3)


def info(name, size):
    i = tarfile.TarInfo(name)
    i.size = size
    i.mode = 0o644
    return i


index = []
files = {}
with open(out, 'wb') as raw:
    with tarfile.open(fileobj=raw, mode='w', format=tarfile.GNU_FORMAT) as tar:
        tar.addfile(info('index.bin', entry.size * len(tiles)),
                    io.BytesIO(bytes(entry.size * len(tiles))))
        for name in sorted(tiles):
            source, offset, size = tiles[name]
            tile = info(name, size)
            data = tar.offset + len(tile.tobuf(tar.format, tar.encoding, tar.errors))
            f = files.setdefault(source, open(source, 'rb'))
            f.seek(offset)
            tar.addfile(tile, f)
            index.append((data, graph_id(name), size))
for f in files.values():
    f.close()
with open(out, 'r+b') as raw:
    raw.seek(tarfile.BLOCKSIZE)  # the data of index.bin, the first member
    for e in index:
        raw.write(entry.pack(*e))
PYTHON
}

# remove_country <routing-land>: takes that country's tiles out of the tar,
# except those another country needs (the border tiles), then its tile
# list; the last country takes the tar with it. The info stays.
remove_country() {
    list="$ROUTING_DIR/$1.kacheln"
    if [ -e "$list" ]; then
        other_tiles "$1" > "$ROUTING_DIR/.andere"
        if [ -s "$ROUTING_DIR/.andere" ]; then
            comm -23 "$list" "$ROUTING_DIR/.andere" > "$ROUTING_DIR/.weg"
            write_tar "$FULL_TAR.new" "$ROUTING_DIR/.weg" "$FULL_TAR"
            mv "$FULL_TAR.new" "$FULL_TAR"
        else
            rm -f "$FULL_TAR"
        fi
        rm -f "$ROUTING_DIR/.andere" "$ROUTING_DIR/.weg"
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
        border=""
        [ -e "$ROUTING_DIR/$name.poly" ] || border=", ohne Grenze"
        printf '%s: Bau %s, Valhalla %s, %s Kacheln%s\n' "${name#routing-}" \
            "$(info_value "$info" bau)" "$(info_value "$info" valhalla)" \
            "$(wc -l < "$ROUTING_DIR/$name.kacheln" 2>/dev/null || echo 0)" "$border"
    done
    if [ -n "$(routing_countries)" ] && [ -n "$(for info in $(routing_countries); do [ -e "${info%.info}.poly" ] || echo x; done)" ]; then
        echo "Hinweis: Ohne die Grenze jedes Landes bleiben Routen nicht in den installierten Ländern. Das Land neu laden behebt das."
    fi
    if [ -e "$FULL_TAR_ASIDE" ]; then
        echo "Das ganze Routing-Paket liegt beiseite: $FULL_TAR_ASIDE"
    fi
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
    remove_country "$name"
    rm -f "$ROUTING_DIR/$name.info" "$ROUTING_DIR/$name.poly"
    if [ -z "$(routing_countries)" ]; then
        # The last country: its folder goes too, if nothing else is in it.
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
    # A country routing package holds its info, its border and its tiles,
    # nothing else.
    if [ "$ROUTING" -eq 1 ]; then
        case "$1" in
            "$PACKAGE.info"|"$PACKAGE.poly"|"$PACKAGE.tar") echo "$ROUTING_DIR/$1" ;;
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
[ "$ROUTING" -eq 1 ] && mkdir -p "$ROUTING_DIR"
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
    if [ -n "$(tile_lists)" ]; then
        # The countries' tiles are in valhalla_tiles.tar; without it there is
        # nothing to append to.
        [ -e "$FULL_TAR" ] ||
            die "$FULL_TAR fehlt, obwohl Länder installiert sind; erst alle Länder entfernen (--remove-routing)"
    elif [ -e "$FULL_TAR" ] && [ -e "$FULL_TAR_ASIDE" ]; then
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
            list="${target%.tar}.kacheln"
            tar -t -f "$target.new" | sort > "$list.new"
            if [ ! -s "$list.new" ] || grep -q -v '\.gph$' "$list.new" ||
                grep -q -e '^/' -e '\.\.' "$list.new"; then
                rm -f "$target.new" "$list.new"
                EXIT_CODE=3 die "$name enthält keine Kacheln, andere Dateien oder Pfade außerhalb des Kachelordners"
            fi
            if [ -z "$(tile_lists)" ]; then
                # The first country: its tar becomes valhalla_tiles.tar, a
                # whole-area one goes aside until the last country is removed.
                if [ -e "$FULL_TAR" ]; then
                    mv "$FULL_TAR" "$FULL_TAR_ASIDE"
                    echo "Das ganze Routing-Paket liegt jetzt als $FULL_TAR_ASIDE beiseite."
                fi
                write_tar "$FULL_TAR.new" "" "$target.new"
            else
                # Left out of the old tar: this country's old tiles no other
                # country needs (an update). The package comes first, so its
                # border tiles win over the copies already in the tar.
                other_tiles "$PACKAGE" > "$ROUTING_DIR/.andere"
                if [ -e "$list" ]; then
                    comm -23 "$list" "$ROUTING_DIR/.andere" > "$ROUTING_DIR/.weg"
                else
                    : > "$ROUTING_DIR/.weg"
                fi
                write_tar "$FULL_TAR.new" "$ROUTING_DIR/.weg" "$target.new" "$FULL_TAR"
                rm -f "$ROUTING_DIR/.andere" "$ROUTING_DIR/.weg"
            fi
            mv "$FULL_TAR.new" "$FULL_TAR"
            rm -f "$target.new"
            "$CHOWN" root:root "$FULL_TAR"
            chmod 0644 "$FULL_TAR"
            mv "$list.new" "$list"
            ;;
        *)
            mv "$target.new" "$target"
            if [ "$target" = "$FULL_TAR" ] && [ -n "$(routing_countries)" ]; then
                # A whole-area package replaced the countries' tar: they are
                # gone, the tar put aside for them is out of date.
                rm -f "$ROUTING_DIR"/routing-*.info "$ROUTING_DIR"/routing-*.poly \
                    "$ROUTING_DIR"/routing-*.kacheln
                echo "Hinweis: Das ganze Routing-Paket ersetzt die Länderpakete. $FULL_TAR_ASIDE (falls da) ist veraltet und kann weg."
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
