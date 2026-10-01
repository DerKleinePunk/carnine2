#!/usr/bin/env bash
set -euo pipefail

# Packs the map data into a package that carnine-install-maps installs on a
# device by itself (from a Nextcloud share or a USB stick), for testers
# without the repository or deploy_maps.sh.
#
#   ./pack_maps.sh <output folder>      e.g. /mnt/d/Mine/Cloud/CarPC/karten-hessen
#
# The sources are the same as deploy_maps.sh's: CARNINE_MAPS_DIR (default
# ~/develop/carnine-maps), CARNINE_MAP_TILES and CARNINE_NAMES_DATABASE. The
# names database must come from the same tiles, see docs/07. The package
# gets each file as <name>.zst under the name it has on the device, INHALT
# (packed and unpacked sizes), SHA256SUMS of the .zst, SHA256SUMS.entpackt
# of the unpacked files and LIESMICH.txt.
#
# Everything is written to <output folder>.tmp first and checked by unpacking
# it again; only then does it move to the final folder, so that a synced
# cloud folder never shows a half-written file under its final name.

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <output folder>" >&2
  exit 1
fi
OUTPUT="${1%/}"
TMP="$OUTPUT.tmp"

MAPS_DIR="${CARNINE_MAPS_DIR:-$HOME/develop/carnine-maps}"
MAP_TILES="${CARNINE_MAP_TILES:-$MAPS_DIR/hessen.mbtiles}"
NAMES_DATABASE="${CARNINE_NAMES_DATABASE:-$MAPS_DIR/germany/hessen_names.db}"
REPLAY_TOUR="$MAPS_DIR/GPS-Adnan-Tour.txt"
VALHALLA_TILES="$MAPS_DIR/valhalla_tiles.tar"
# zstd level: -19 gains about 4 % over -9 on the tiles but takes minutes.
LEVEL="${CARNINE_PACK_LEVEL:-9}"

if [[ -e "$OUTPUT" ]]; then
  echo "ERROR: $OUTPUT exists already; pick a new name or remove it first" >&2
  exit 1
fi

# Device name and source, in the order carnine-install-maps unpacks them.
SOURCES=(
  "map.mbtiles=$MAP_TILES"
  "germany_names.db=$NAMES_DATABASE"
  "GPS-Adnan-Tour.txt=$REPLAY_TOUR"
  "valhalla_tiles.tar=$VALHALLA_TILES"
)
for entry in "${SOURCES[@]}"; do
  if [[ ! -f "${entry#*=}" ]]; then
    echo "ERROR: map data not found: ${entry#*=} (set CARNINE_MAPS_DIR)" >&2
    exit 1
  fi
done

rm -rf "$TMP"
mkdir -p "$TMP"
printf '# datei\tgepackt\tentpackt\n' > "$TMP/INHALT"
: > "$TMP/SHA256SUMS.entpackt"
for entry in "${SOURCES[@]}"; do
  name="${entry%%=*}"
  source="${entry#*=}"
  echo "Packing $name from $source..."
  zstd -q -T0 "-$LEVEL" -f "$source" -o "$TMP/$name.zst"
  unpacked_sum=$(sha256sum "$source" | cut -d ' ' -f 1)
  # Unpacking again proves the .zst before it is handed out.
  if [[ "$(zstd -q -d -c "$TMP/$name.zst" | sha256sum | cut -d ' ' -f 1)" != "$unpacked_sum" ]]; then
    echo "ERROR: $name.zst does not unpack to $source" >&2
    exit 1
  fi
  printf '%s  %s\n' "$unpacked_sum" "$name" >> "$TMP/SHA256SUMS.entpackt"
  printf '%s.zst\t%s\t%s\n' "$name" "$(stat -c %s "$TMP/$name.zst")" "$(stat -c %s "$source")" >> "$TMP/INHALT"
done
(cd "$TMP" && sha256sum ./*.zst | sed 's#  \./#  #' > SHA256SUMS)

# For people who open the folder; CRLF so that Windows editors show it right.
sed 's/$/\r/' > "$TMP/LIESMICH.txt" <<EOF
Carnine2 – Kartendaten ($(basename "$OUTPUT"))

Installieren auf dem Gerät: sudo carnine-install-maps
(fragt nach dem Freigabe-Link; von einem USB-Stick: --dir <dieser Ordner>).
Gepackt mit zstd, entpackt $(awk -F '\t' '!/^#/ { s += $3 } END { printf "%.1f", s / 1e9 }' "$TMP/INHALT" | tr . ,) GB.

  map.mbtiles.zst          Vektorkacheln             -> /var/lib/carnine/maps/map.mbtiles
  germany_names.db.zst     Ortsnamen für die Suche   -> /var/lib/carnine/maps/germany_names.db
  GPS-Adnan-Tour.txt.zst   Messe-Tour (NMEA)         -> /var/lib/carnine/maps/GPS-Adnan-Tour.txt
  valhalla_tiles.tar.zst   Routing                   -> /var/lib/valhalla/valhalla_tiles.tar

INHALT               Größen gepackt und entpackt
SHA256SUMS           Prüfsummen der .zst-Dateien
SHA256SUMS.entpackt  Prüfsummen der entpackten Dateien

Herkunft der Daten: © OpenStreetMap-Mitwirkende, Open Database License (ODbL) 1.0,
https://www.openstreetmap.org/copyright
Kacheln im OpenMapTiles-Schema, gebaut mit tilemaker; Routing mit Valhalla.
EOF

# File by file rather than renaming the folder: the cloud client on Windows
# holds the folder it syncs and refuses the rename. INHALT goes last, since
# carnine-install-maps starts with it.
mkdir "$OUTPUT"
for file in "$TMP"/*.zst "$TMP"/SHA256SUMS "$TMP"/SHA256SUMS.entpackt "$TMP"/LIESMICH.txt "$TMP"/INHALT; do
  mv "$file" "$OUTPUT/"
done
rmdir "$TMP"
echo "Package ready: $OUTPUT"
