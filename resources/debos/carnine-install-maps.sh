#!/bin/sh
# Installs a map package (tiles, names, demo tour, Valhalla routing tiles) on
# the device itself, so that a tester needs neither the repository nor
# deploy_maps.sh. Installed as /usr/local/sbin/carnine-install-maps.
#
#   sudo carnine-install-maps                      asks for the share link
#   sudo carnine-install-maps --link <share-link>  a Nextcloud share link
#   sudo carnine-install-maps --dir <folder>       a package folder, e.g. on a USB stick
#
# A package is a folder (default name karten-hessen) holding <file>.zst for
# each file, INHALT (packed and unpacked sizes), SHA256SUMS (of the .zst) and
# SHA256SUMS.entpackt (of the unpacked files). The share link is not built
# in: whoever hands out the package hands out the link.
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

PACKAGE=karten-hessen
LINK=""
SOURCE_DIR=""
SHOW_SOURCE=0

usage() {
    echo "Aufruf: sudo carnine-install-maps [--link <freigabe-link>] [--dir <ordner>] [--package <name>]" >&2
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
        *) usage ;;
    esac
done

if [ "$(id -u)" -ne 0 ] && [ -z "${CARNINE_SKIP_ROOT_CHECK:-}" ] && [ "$SHOW_SOURCE" -eq 0 ]; then
    die "bitte mit sudo aufrufen: sudo carnine-install-maps"
fi

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

target_of() {
    case "$1" in
        map.mbtiles|germany_names.db|GPS-Adnan-Tour.txt) echo "$MAPS_DIR/$1" ;;
        valhalla_tiles.tar) echo "$VALHALLA_DIR/$1" ;;
        *) return 1 ;;
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
echo "Hole die Paketliste von $BASE ..."
for list in INHALT SHA256SUMS SHA256SUMS.entpackt; do
    fetch "$list" "$WORK_DIR/$list" quiet || die "konnte $list nicht laden (Link oder Paketname falsch?)"
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
    if [ -e "$target" ] && [ "$(size_of "$target")" = "$unpacked_size" ] &&
        grep -qx "$sum $unpacked_size $target" "$STAMP" 2>/dev/null; then
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
    mv "$target.new" "$target"
    rm -f "$WORK_DIR/$packed"
    { grep -v " $target\$" "$STAMP" 2>/dev/null || true; echo "$sum $unpacked_size $target"; } > "$STAMP.new"
    mv "$STAMP.new" "$STAMP"
done < "$TODO_LIST"

rm -rf "$WORK_DIR"
echo "Fertig. Die Karte ist nach dem Neustart der Dienste in etwa einer Minute da."
