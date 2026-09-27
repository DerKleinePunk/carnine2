#!/bin/bash
# Writes an NMEA log of a car standing at one place, for the backend's replay
# source (navigation.position_source = "replay"): one GGA and one RMC per
# second, speed 0, no course.
#
# usage: standstill-nmea.sh LAT LON SECONDS > file.nmea
#   e.g. standstill-nmea.sh 50.31165 9.45940 600
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 LAT LON SECONDS" >&2
  exit 2
fi
lat=$1 lon=$2 seconds=$3

# ddmm.mmmm / dddmm.mmmm and the hemisphere letters.
read -r lat_nmea lat_hemi lon_nmea lon_hemi < <(awk -v lat="$lat" -v lon="$lon" 'BEGIN {
  ns = lat < 0 ? "S" : "N"; ew = lon < 0 ? "W" : "E"
  if (lat < 0) lat = -lat; if (lon < 0) lon = -lon
  printf "%02d%07.4f %s %03d%07.4f %s\n", int(lat), (lat - int(lat)) * 60, ns, int(lon), (lon - int(lon)) * 60, ew
}')

sentence() {
  local body=$1 sum=0 i
  for ((i = 0; i < ${#body}; i++)); do
    sum=$((sum ^ $(printf '%d' "'${body:i:1}")))
  done
  printf '$%s*%02X\r\n' "$body" "$sum"
}

start=$(date -u +%s)
for ((s = 0; s < seconds; s++)); do
  t=$(date -u -d "@$((start + s))" +%H%M%S)
  d=$(date -u -d "@$((start + s))" +%d%m%y)
  sentence "GPGGA,$t.000,$lat_nmea,$lat_hemi,$lon_nmea,$lon_hemi,1,09,0.9,180.0,M,48.0,M,,"
  sentence "GPRMC,$t.000,A,$lat_nmea,$lat_hemi,$lon_nmea,$lon_hemi,0.00,,$d,,,A"
done
