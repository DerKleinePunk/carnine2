#!/usr/bin/env bash
set -euo pipefail

# Copies the map data onto a Carnine device (ADR-021). The image ships
# Valhalla and the [navigation] drop-in but no data: tiles, names and routing
# tiles are about 7.5 GB, which would more than triple the image.
#
#   ./deploy_maps.sh [user@host] [--no-restart]
#
# The source folder (CARNINE_MAPS_DIR, default ~/develop/carnine-maps) holds:
#   hessen.mbtiles       vector tiles, installed as map.mbtiles
#   germany_names.db     place names for the search
#   GPS-Adnan-Tour.txt   NMEA tour the trade fair stand replays
#   valhalla_tiles.tar   Valhalla routing tiles
# SHA256SUMS beside them, if present, is checked before anything is copied.
#
# rsync keeps sizes and times, so running it again only copies what changed.
# Afterwards Valhalla, backend and frontend restart to pick the data up; the
# backend restart closes the HDMI audio stream once (the known pop).

TARGET="pi@carnine-pc"
RESTART=1
for argument in "$@"; do
  case "$argument" in
    --no-restart) RESTART=0 ;;
    -*)
      echo "Usage: $0 [user@host] [--no-restart]" >&2
      exit 1
      ;;
    *) TARGET="$argument" ;;
  esac
done

MAPS_DIR="${CARNINE_MAPS_DIR:-$HOME/develop/carnine-maps}"
MAP_TILES="${CARNINE_MAP_TILES:-$MAPS_DIR/hessen.mbtiles}"
NAMES_DATABASE="$MAPS_DIR/germany_names.db"
REPLAY_TOUR="$MAPS_DIR/GPS-Adnan-Tour.txt"
VALHALLA_TILES="$MAPS_DIR/valhalla_tiles.tar"

for file in "$MAP_TILES" "$NAMES_DATABASE" "$REPLAY_TOUR" "$VALHALLA_TILES"; do
  if [[ ! -f "$file" ]]; then
    echo "ERROR: map data not found: $file (set CARNINE_MAPS_DIR)" >&2
    exit 1
  fi
done

if [[ -f "$MAPS_DIR/SHA256SUMS" ]]; then
  echo "Checking $MAPS_DIR/SHA256SUMS..."
  (cd "$MAPS_DIR" && sha256sum --check --quiet SHA256SUMS)
fi

# --rsync-path runs the remote side as root, which the target directories need.
copy() {
  rsync -t --partial --info=progress2 --rsync-path="sudo rsync" "$1" "$TARGET:$2"
}

echo "Copying map data to $TARGET..."
copy "$MAP_TILES" /var/lib/carnine/maps/map.mbtiles
copy "$NAMES_DATABASE" /var/lib/carnine/maps/germany_names.db
copy "$REPLAY_TOUR" /var/lib/carnine/maps/GPS-Adnan-Tour.txt
copy "$VALHALLA_TILES" /var/lib/valhalla/valhalla_tiles.tar

# The backend and frontend run as carnine; Valhalla runs with a dynamic user
# and so needs the routing tiles world-readable.
ssh "$TARGET" bash -s -- "$RESTART" <<'REMOTE_SCRIPT'
set -euo pipefail
RESTART="$1"
sudo chown carnine:carnine /var/lib/carnine/maps/map.mbtiles \
  /var/lib/carnine/maps/germany_names.db /var/lib/carnine/maps/GPS-Adnan-Tour.txt
sudo chmod 0640 /var/lib/carnine/maps/map.mbtiles \
  /var/lib/carnine/maps/germany_names.db /var/lib/carnine/maps/GPS-Adnan-Tour.txt
sudo chown root:root /var/lib/valhalla/valhalla_tiles.tar
sudo chmod 0644 /var/lib/valhalla/valhalla_tiles.tar
if [[ "$RESTART" -eq 1 ]]; then
  sudo systemctl restart valhalla.service carnine-backend.service carnine-frontend.service
  sudo systemctl --no-pager is-active valhalla.service carnine-backend.service carnine-frontend.service
fi
REMOTE_SCRIPT

echo "Map data deployed."
