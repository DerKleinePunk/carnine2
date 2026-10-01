#!/usr/bin/env bash
set -euo pipefail

# Copies the map data onto a Carnine device (ADR-021). The image ships
# Valhalla and the [navigation] drop-in but no data: tiles, names and routing
# tiles are about 7.5 GB, which would more than triple the image. Devices
# without a development machine use carnine-install-maps instead.
#
#   ./deploy_maps.sh [user@host] [--dach] [--no-restart]
#
# Hessen (the default, as in the testers' package) comes from the source
# folder CARNINE_MAPS_DIR (default ~/develop/carnine-maps):
#   hessen.mbtiles             vector tiles, installed as map.mbtiles
#   germany/hessen_names.db    place names for the search, installed as
#                              germany_names.db; it must come from the same
#                              tiles, see docs/07
#   GPS-Adnan-Tour.txt         NMEA tour the trade fair stand replays
#   valhalla_tiles.tar         Valhalla routing tiles (all of Germany)
# --dach takes tiles, names and routing tiles of Germany, Austria and
# Switzerland from CARNINE_DACH_DIR (default $CARNINE_MAPS_DIR/dach, a copy of
# the map project's build: dach.mbtiles, dach_names.db, valhalla_tiles.tar);
# our own test devices run with it. CARNINE_MAP_TILES and
# CARNINE_NAMES_DATABASE name other files. Each file is checked against the
# SHA256SUMS in its own folder, if that lists it, before anything is copied.
#
# The device must have room for the new files plus a copy of the largest one,
# which rsync writes beside the old file before it replaces it; that is
# checked before any service is stopped. map_region in the navigation drop-in
# is set to the region deployed.
#
# rsync keeps sizes and times, so running it again only copies what changed.
# Afterwards Valhalla, backend and frontend restart to pick the data up; the
# backend restart closes the HDMI audio stream once (the known pop).
#
# CARNINE_SSH and CARNINE_RSYNC replace ssh and rsync for the tests.

usage() {
  echo "Usage: $0 [user@host] [--dach] [--no-restart]" >&2
  exit 1
}

TARGET="pi@carnine-pc"
RESTART=1
REGION=Hessen
for argument in "$@"; do
  case "$argument" in
    --no-restart) RESTART=0 ;;
    --dach) REGION=DACH ;;
    -*) usage ;;
    *) TARGET="$argument" ;;
  esac
done

SSH="${CARNINE_SSH:-ssh}"
RSYNC="${CARNINE_RSYNC:-rsync}"
MAPS_DIR="${CARNINE_MAPS_DIR:-$HOME/develop/carnine-maps}"
REPLAY_TOUR="$MAPS_DIR/GPS-Adnan-Tour.txt"
if [[ "$REGION" == DACH ]]; then
  DACH_DIR="${CARNINE_DACH_DIR:-$MAPS_DIR/dach}"
  MAP_TILES="${CARNINE_MAP_TILES:-$DACH_DIR/dach.mbtiles}"
  NAMES_DATABASE="${CARNINE_NAMES_DATABASE:-$DACH_DIR/dach_names.db}"
  VALHALLA_TILES="$DACH_DIR/valhalla_tiles.tar"
else
  MAP_TILES="${CARNINE_MAP_TILES:-$MAPS_DIR/hessen.mbtiles}"
  NAMES_DATABASE="${CARNINE_NAMES_DATABASE:-$MAPS_DIR/germany/hessen_names.db}"
  VALHALLA_TILES="$MAPS_DIR/valhalla_tiles.tar"
fi

# Source and place on the device, in the order they are copied.
FILES=(
  "$MAP_TILES=/var/lib/carnine/maps/map.mbtiles"
  "$NAMES_DATABASE=/var/lib/carnine/maps/germany_names.db"
  "$REPLAY_TOUR=/var/lib/carnine/maps/GPS-Adnan-Tour.txt"
  "$VALHALLA_TILES=/var/lib/valhalla/valhalla_tiles.tar"
)

echo "Region $REGION:"
for entry in "${FILES[@]}"; do
  file="${entry%=*}"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: map data not found: $file (set CARNINE_MAPS_DIR or CARNINE_DACH_DIR)" >&2
    exit 1
  fi
  sums="$(dirname "$file")/SHA256SUMS"
  name="$(basename "$file")"
  expected=$(awk -v name="$name" '$2 == name || $2 == "*" name { print $1 }' "$sums" 2>/dev/null || true)
  if [[ -z "$expected" ]]; then
    echo "  $file (no checksum in $sums)"
    continue
  fi
  echo "  $file, checking..."
  if [[ "$(sha256sum "$file" | cut -d ' ' -f 1)" != "$expected" ]]; then
    echo "ERROR: $file does not match $sums" >&2
    exit 1
  fi
done

# Room on the device: what the new files add over the old ones, plus the
# largest new file once more for rsync's temporary copy.
sizes=()
targets=()
for entry in "${FILES[@]}"; do
  sizes+=("$(stat -c %s "${entry%=*}")")
  targets+=("${entry#*=}")
done
# One number per line: the free bytes, then the size of each old file.
mapfile -t answer < <("$SSH" "$TARGET" "df -B1 --output=avail /var/lib/carnine/maps | tail -n 1 | tr -d ' '
  for file in ${targets[*]}; do sudo stat -c %s \"\$file\" 2>/dev/null || echo 0; done")
if [[ "${#answer[@]}" -ne $((${#targets[@]} + 1)) ]]; then
  echo "ERROR: could not read the free space on $TARGET" >&2
  exit 1
fi
free=${answer[0]}
old=("${answer[@]:1}")
needed=0
largest=0
for i in "${!sizes[@]}"; do
  needed=$((needed + sizes[i] - ${old[i]:-0}))
  if [[ "${sizes[i]}" -gt "$largest" ]]; then largest=${sizes[i]}; fi
done
needed=$((needed + largest))
if [[ "$free" -lt "$needed" ]]; then
  echo "ERROR: $TARGET has $((free / 1000000000)) GB free, $REGION needs $((needed / 1000000000)) GB" >&2
  exit 1
fi

# --rsync-path runs the remote side as root, which the target directories need.
copy() {
  "$RSYNC" -t --partial --info=progress2 --rsync-path="sudo rsync" "$1" "$TARGET:$2"
}

# The frontend reads the tiles and the backend the names while they are
# replaced; stopping both first keeps them off half-copied files. The names
# database comes without WAL since local_map 0.5.0, and a -wal/-shm left from
# the old one makes SQLite call the new file malformed.
if [[ "$RESTART" -eq 1 ]]; then
  "$SSH" "$TARGET" "sudo systemctl stop carnine-frontend.service carnine-backend.service &&
    sudo rm -f /var/lib/carnine/maps/germany_names.db-wal /var/lib/carnine/maps/germany_names.db-shm"
else
  echo "Note: with --no-restart, delete germany_names.db-wal/-shm on $TARGET before the next start."
fi

echo "Copying map data to $TARGET..."
for entry in "${FILES[@]}"; do
  copy "${entry%=*}" "${entry#*=}"
done

# The backend and frontend run as carnine; Valhalla runs with a dynamic user
# and so needs the routing tiles world-readable.
"$SSH" "$TARGET" bash -s -- "$RESTART" "$REGION" <<'REMOTE_SCRIPT'
set -euo pipefail
RESTART="$1"
REGION="$2"
sudo chown carnine:carnine /var/lib/carnine/maps/map.mbtiles \
  /var/lib/carnine/maps/germany_names.db /var/lib/carnine/maps/GPS-Adnan-Tour.txt
sudo chmod 0640 /var/lib/carnine/maps/map.mbtiles \
  /var/lib/carnine/maps/germany_names.db /var/lib/carnine/maps/GPS-Adnan-Tour.txt
sudo chown root:root /var/lib/valhalla/valhalla_tiles.tar
sudo chmod 0644 /var/lib/valhalla/valhalla_tiles.tar
sudo sed -i "s/^map_region = .*/map_region = \"$REGION\"/" /etc/carnine/config.d/10-navigation.toml
if [[ "$RESTART" -eq 1 ]]; then
  sudo systemctl restart valhalla.service carnine-backend.service carnine-frontend.service
  sudo systemctl --no-pager is-active valhalla.service carnine-backend.service carnine-frontend.service
fi
REMOTE_SCRIPT

echo "Map data ($REGION) deployed."
