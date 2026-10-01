#!/bin/bash
# Drives carnine-pc through a scripted demo for filming the display: page
# switches and on-screen keyboard input as synthetic touches (touchplay), the
# player over gRPC (media_grpc_client through an SSH tunnel to the backend
# socket).
#
# usage: demo.sh prepare     copy tools and music to the Pi, plan the drive to
#                            Frankfurt, switch the backend to the demo GPS
#                            mouse standing in Steinau, start on "home"
#        demo.sh run FILE    play a demo file (see frankfurt.demo)
#        demo.sh restore     back to the Pi's own position source
#
# Demo file commands, one per line (# starts a comment):
#   say TEXT                  cue on this terminal, nothing on the Pi
#   page home|maps|media|camera|controls|settings
#   tap X Y | swipe X Y DX DY [MS] | pinch CX CY FROM TO [MS] | wait MS
#   type TEXT                 letters, space, capitals on the on-screen keyboard
#   key done|backspace|space|shift
#   drive                     the demo GPS mouse starts driving the planned route
#   play PATH                 MediaService.Play with that file
#   cli ARGS...               any media_grpc_client command
# Coordinates are logical pixels on the 1024x600 panel, taken from the
# frontend layout (side_menu.dart, keyboard_panel.dart, destination_search.dart).
# Full description: docs/25-demo-and-touch-tools.md.
# The remote commands are meant to expand here, before they go over SSH.
# shellcheck disable=SC2029
set -euo pipefail

PI=${CARNINE_DEMO_PI:-pi@192.168.2.51}
PORT=${CARNINE_DEMO_PORT:-50061}
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
BACKEND_DIR=$ROOT/src/backend
CLIENT=$BACKEND_DIR/target/debug/examples/media_grpc_client
REMOTE_DIR=/home/pi/demo
MEDIA_DIR=/var/lib/carnine/media/demo
TRACK_FILE=/var/lib/carnine/maps/demo-track.json
GPS_PIPE=/var/lib/carnine/maps/demo-gps.fifo
GPS_UNIT=carnine-demo-gps
DROP_IN=/etc/carnine/config.d/90-demo.toml
# Seconds of the drive per second of video, and fixes per second of video.
FACTOR=${CARNINE_DEMO_FACTOR:-10}
HZ=${CARNINE_DEMO_HZ:-2}
# Steinau an der Straße and Frankfurt am Main, from the names database
# (SearchPlaces); the destination is the first hit the demo taps.
STEINAU_LAT=50.31165
STEINAU_LON=9.45940
FRANKFURT_LAT=50.11064715743284
FRANKFURT_LON=8.682090640068054

log() { printf '%s %s\n' "$(date +%T)" "$*"; }

tunnel() {
  if ! ss -ltn | grep -q "127.0.0.1:$PORT "; then
    ssh -f -N -L "127.0.0.1:$PORT:/run/carnine/carnine.sock" "$PI"
  fi
}

client() {
  [[ -x $CLIENT ]] || (cd "$BACKEND_DIR" && cargo build -q --example media_grpc_client)
  tunnel
  "$CLIENT" "http://127.0.0.1:$PORT" "$@"
}

wait_for_backend() {
  for _ in $(seq 1 30); do
    client version >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo "backend did not come back" >&2
  return 1
}

prepare() {
  local build
  build=$(mktemp -d)
  aarch64-linux-gnu-gcc -O2 -Wall -static -o "$build/touchplay" "$HERE/touchplay.c"
  # A pipe stands in for the GPS mouse (demo_gps.py): unlike the replay
  # source the map then loads no route of its own.
  printf '%s\n' '# Demo drop-in from resources/tools/demo/demo.sh; demo.sh restore removes it.' \
    '[navigation]' 'position_source = "serial"' "serial_device = \"$GPS_PIPE\"" \
    >"$build/90-demo.toml"
  ssh "$PI" "mkdir -p $REMOTE_DIR && command -v python3 >/dev/null" \
    || { echo "python3 missing on $PI (demo_gps.py)" >&2; exit 1; }
  scp -q "$build/touchplay" "$build/90-demo.toml" "$HERE/demo_gps.py" "$PI:$REMOTE_DIR/"
  scp -q "$ROOT"/resources/musik/*.mp3 "$PI:$REMOTE_DIR/"
  rm -rf "$build"
  log "tools, music and drop-in on the Pi"
  # Planned on the Pi's own Valhalla, so the drive is the route the UI shows.
  ssh "$PI" "python3 $REMOTE_DIR/demo_gps.py plan $STEINAU_LAT $STEINAU_LON \
      $FRANKFURT_LAT $FRANKFURT_LON $REMOTE_DIR/demo-track.json"
  ssh "$PI" "sudo systemctl stop $GPS_UNIT 2>/dev/null; sudo systemctl reset-failed $GPS_UNIT 2>/dev/null; \
    sudo install -d -o carnine -g carnine $MEDIA_DIR \
    && sudo install -o carnine -g carnine -m 0644 $REMOTE_DIR/*.mp3 $MEDIA_DIR/ \
    && sudo install -o carnine -g carnine -m 0644 $REMOTE_DIR/demo-track.json $TRACK_FILE \
    && sudo rm -f $GPS_PIPE && sudo -u carnine mkfifo -m 0600 $GPS_PIPE \
    && sudo systemd-run -q --unit=$GPS_UNIT --uid=carnine --gid=carnine \
      python3 -u $REMOTE_DIR/demo_gps.py feed $TRACK_FILE $GPS_PIPE --factor $FACTOR --hz $HZ \
    && sudo install -m 0644 $REMOTE_DIR/90-demo.toml $DROP_IN \
    && sudo systemctl restart carnine-backend"
  wait_for_backend
  client stop >/dev/null 2>&1 || true
  client rescan >/dev/null
  client save-ui-state home >/dev/null
  # The frontend reads the library and the start page when it starts.
  ssh "$PI" "sudo systemctl restart carnine-frontend"
  sleep 12
  client nav-status | head -3
  log "ready: the car stands in Steinau, the UI is on home"
}

# The GPS mouse leaves Steinau (demo file command drive). -n: run reads the
# demo file on stdin, ssh would swallow the rest of it.
drive() {
  ssh -n "$PI" "sudo systemctl kill -s USR1 --kill-whom=main $GPS_UNIT"
}

restore() {
  ssh "$PI" "sudo systemctl stop $GPS_UNIT 2>/dev/null; sudo systemctl reset-failed $GPS_UNIT 2>/dev/null; \
    sudo rm -f $DROP_IN $GPS_PIPE && sudo systemctl restart carnine-backend"
  wait_for_backend
  client nav-status | head -3
  log "backend back on its own position source"
}

# --- touch input -----------------------------------------------------------

TOUCH_IN=
TOUCH_OUT=

gesture_start() {
  coproc TOUCH { ssh "$PI" "sudo $REMOTE_DIR/touchplay"; }
  TOUCH_IN=${TOUCH[1]}
  TOUCH_OUT=${TOUCH[0]}
  local reply
  read -r reply <&"$TOUCH_OUT"
  [[ $reply == ready ]] || { echo "touchplay: $reply" >&2; exit 1; }
}

gesture() {
  local reply
  echo "$*" >&"$TOUCH_IN"
  read -r reply <&"$TOUCH_OUT"
  [[ $reply == ok ]] || { echo "touchplay: $reply ($*)" >&2; exit 1; }
}

# Side menu: 96 px wide, items 72 px high below the brand header.
page_y() {
  case $1 in
    home) echo 104 ;; maps) echo 176 ;; media) echo 248 ;;
    # camera was the climate page until October 2026; old scripts keep working.
    camera|climate) echo 320 ;; controls) echo 392 ;; settings) echo 464 ;;
    *) echo "unknown page: $1" >&2; exit 1 ;;
  esac
}

# On-screen keyboard (keyboard_layout.dart): rows 66 px high from y 324, one
# key unit 1000/13 px; the rows are centred, hence the different starts.
KEY_ROWS=(qwertyuiop asdfghjkl zxcvbnm)
KEY_ROW_START=(88.9 204.3 358.2)

key_xy() {
  local c=$1 row keys i
  for row in 0 1 2; do
    keys=${KEY_ROWS[$row]}
    for ((i = 0; i < ${#keys}; i++)); do
      if [[ ${keys:i:1} == "$c" ]]; then
        awk -v s="${KEY_ROW_START[$row]}" -v i="$i" -v r="$row" \
          'BEGIN { printf "%d %d\n", s + i * 76.92 + 0.5, 357 + r * 66 }'
        return
      fi
    done
  done
  echo "no key for '$c'" >&2
  exit 1
}

key() {
  case $1 in
    done) gesture tap 897 555 ;;
    backspace) gesture tap 897 357 ;;
    space) gesture tap 435 555 ;;
    shift) gesture tap 243 489 ;;
    *) echo "unknown key: $1" >&2; exit 1 ;;
  esac
}

type_text() {
  local text=$1 i c lower x y
  for ((i = 0; i < ${#text}; i++)); do
    c=${text:i:1}
    if [[ $c == " " ]]; then
      key space
    else
      lower=${c,,}
      # Shift is one-shot: tapped before each capital.
      [[ $c != "$lower" ]] && { key shift; gesture wait 120; }
      read -r x y < <(key_xy "$lower")
      gesture tap "$x" "$y"
    fi
    gesture wait 180
  done
}

run() {
  local file=$1 line cmd rest args
  [[ -f $file ]] || { echo "no demo file: $file" >&2; exit 1; }
  tunnel
  gesture_start
  log "running $file"
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    line=${line%"${line##*[![:space:]]}"}
    [[ -z $line ]] && continue
    cmd=${line%% *}
    rest=${line#"$cmd"}
    rest=${rest# }
    case $cmd in
      say) log ">> $rest" ;;
      page) gesture tap 48 "$(page_y "$rest")" ;;
      tap | swipe | pinch | wait) gesture "$line" ;;
      type) type_text "$rest" ;;
      key) key "$rest" ;;
      drive) drive ;;
      play) client play "$rest" >/dev/null ;;
      cli) read -ra args <<<"$rest" && client "${args[@]}" ;;
      *) echo "unknown command: $line" >&2; exit 1 ;;
    esac
  done <"$file"
  exec {TOUCH_IN}>&-
  # TOUCH_PID comes from coproc.
  # shellcheck disable=SC2153
  wait "$TOUCH_PID" 2>/dev/null || true
  log "done"
}

case ${1:-} in
  prepare) prepare ;;
  run) run "${2:?demo file}" ;;
  restore) restore ;;
  *) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
