#!/usr/bin/env bash
set -euo pipefail

# Runs backend and frontend locally in WSL2, with the frontend under
# ivi-homescreen (wayland-egl on WSLg) as on the Pi instead of the GTK runner of
# `flutter run -d linux`. See docs/07-deployment.md "Local development (WSL2):
# frontend under ivi-homescreen".
#
#   ./run_wsl.sh             build what changed, then start both
#   ./run_wsl.sh --no-build  start the last build again
#
# Everything it writes stays under build/wsl-dev/. Ctrl+C in the frontend
# window's terminal stops the frontend, the backend and the Valhalla tunnel.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/src/backend"
FRONTEND_DIR="$ROOT_DIR/src/frontend"
PROTO_DIR="$ROOT_DIR/src/proto"
LOG_DIR="$ROOT_DIR/build-logs"
EMB_WORKSPACE="${CARNINE_EMB_WORKSPACE:-$HOME/develop/emb-workspace}"
EMB_EMBEDDER_DIR="$EMB_WORKSPACE/app/ivi-homescreen"
EMB_BACKEND="wayland-egl"
FLUTTER_BIN="$EMB_WORKSPACE/flutter/bin/flutter"
FRONTEND_STAGING_DIR="$ROOT_DIR/build/emb-app-local/carnine_frontend"
# Debug by default: the Dart VM service stays reachable and a local start does
# not pay for the AOT step.
FRONTEND_BUILD_MODE="${CARNINE_FRONTEND_BUILD_MODE:-debug}"
DEV_DIR="$ROOT_DIR/build/wsl-dev"
MAPS_DIR="${CARNINE_MAPS_DIR:-$HOME/develop/carnine-maps}"
MAP_TILES="${CARNINE_MAP_TILES:-$MAPS_DIR/hessen.mbtiles}"
NAMES_DATABASE="${CARNINE_NAMES_DATABASE:-$MAPS_DIR/germany_names.db}"
MEDIA_DIR="${CARNINE_WSL_MEDIA:-$DEV_DIR/media}"
# There is no local Valhalla; routing borrows the Pi's through an SSH tunnel.
# Empty disables it, and the map then shows no route.
VALHALLA_TUNNEL="${CARNINE_VALHALLA_TUNNEL-pi@192.168.2.51}"
VALHALLA_PORT=8002
WINDOW_WIDTH=1024
WINDOW_HEIGHT=600

BUILD=1
case "${1:-}" in
  "") ;;
  --no-build) BUILD=0 ;;
  *)
    echo "Usage: $0 [--no-build]" >&2
    exit 1
    ;;
esac

case "$FRONTEND_BUILD_MODE" in
  release|profile|debug) ;;
  *)
    echo "[wsl] ERROR: Invalid CARNINE_FRONTEND_BUILD_MODE: $FRONTEND_BUILD_MODE (expected release, profile or debug)"
    exit 1
    ;;
esac

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  echo "[wsl] ERROR: WAYLAND_DISPLAY is not set; ivi-homescreen needs WSLg's Wayland compositor."
  exit 1
fi
if ! command -v emb >/dev/null 2>&1; then
  echo "[wsl] ERROR: emb not found in PATH."
  echo "[wsl] Hint: dart install emb_cli"
  exit 1
fi
if [[ ! -x "$FLUTTER_BIN" || ! -f "$EMB_EMBEDDER_DIR/CMakeLists.txt" ]]; then
  echo "[wsl] ERROR: emb workspace is missing or incomplete: $EMB_WORKSPACE"
  echo "[wsl] Hint: set CARNINE_EMB_WORKSPACE or provision it as described in docs/07-deployment.md."
  exit 1
fi
for file in "$MAP_TILES" "$NAMES_DATABASE"; do
  if [[ ! -f "$file" ]]; then
    echo "[wsl] WARNING: map data not found: $file (set CARNINE_MAPS_DIR); the maps page stays empty"
  fi
done

mkdir -p "$LOG_DIR" "$DEV_DIR/covers" "$DEV_DIR/logs" "$MEDIA_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
EMB_LOG="$LOG_DIR/wsl-${TIMESTAMP}-emb.log"
BUNDLE_FILE="$DEV_DIR/bundle-path"

if [[ "$BUILD" -eq 1 ]]; then
  echo "[wsl] Generating shared protobuf Dart stubs..."
  (
    cd "$FRONTEND_DIR"
    protoc -I "$PROTO_DIR" --dart_out=grpc:lib/lib "$PROTO_DIR/carnine.proto"
  )

  echo "[wsl] Staging frontend for emb: $FRONTEND_STAGING_DIR"
  mkdir -p "$FRONTEND_STAGING_DIR"
  rsync -a --delete \
    --exclude=/build/ --exclude=/.dart_tool/ \
    --exclude='/libapp.so*' --exclude='*.symbols' --exclude='obfuscation_map*' \
    "$FRONTEND_DIR/" "$FRONTEND_STAGING_DIR/"
  (
    cd "$FRONTEND_STAGING_DIR"
    "$FLUTTER_BIN" pub get
  )

  echo "[wsl] Building ivi-homescreen bundle (local x86_64 / $EMB_BACKEND, $FRONTEND_BUILD_MODE)..."
  (
    cd "$EMB_EMBEDDER_DIR"
    emb cross . --build --backend "$EMB_BACKEND" \
      --app "$FRONTEND_STAGING_DIR" --mode "$FRONTEND_BUILD_MODE" \
      -D DISABLE_PLUGINS=ON \
      -w "$EMB_WORKSPACE"
  ) 2>&1 | tee "$EMB_LOG"
  # The bundle path carries a hash over the defines, so it is taken from emb's
  # own report rather than predicted.
  sed -n "s/^.*$EMB_BACKEND: runnable → \([^[:space:]]*\).*/\1/p" "$EMB_LOG" | tail -n 1 > "$BUNDLE_FILE"

  echo "[wsl] Building backend (debug)..."
  (
    cd "$BACKEND_DIR"
    cargo build
  )
fi

FRONTEND_BUNDLE="$(cat "$BUNDLE_FILE" 2>/dev/null || true)"
if [[ -z "$FRONTEND_BUNDLE" || ! -x "$FRONTEND_BUNDLE/homescreen" ]]; then
  echo "[wsl] ERROR: ivi-homescreen bundle not found; run $0 without --no-build first"
  exit 1
fi

# The replay tour ships with local_map; take it from the revision the frontend
# actually resolved.
LOCAL_MAP_REF="$(grep -A6 '^  local_map:' "$FRONTEND_STAGING_DIR/pubspec.lock" | sed -n 's/^ *resolved-ref: "\(.*\)"/\1/p')"
REPLAY_FILE="${CARNINE_REPLAY_FILE:-$HOME/.pub-cache/git/flutter_local_map-$LOCAL_MAP_REF/scripts/GpsTest/GPS-Adnan-Tour.txt}"
if [[ ! -f "$REPLAY_FILE" ]]; then
  echo "[wsl] WARNING: replay tour not found: $REPLAY_FILE (set CARNINE_REPLAY_FILE); no own position"
fi

if [[ -z "$(find "$MEDIA_DIR" -type f -print -quit)" ]]; then
  cp "$ROOT_DIR/resources/musik/1-Here We Go Now (Single Edit).mp3" "$MEDIA_DIR/"
fi

# Regenerated on every start so it always matches the paths above; the
# versioned resources/config/carnine.toml stays the production one.
SOCKET_PATH="$DEV_DIR/carnine.sock"
cat > "$DEV_DIR/config.toml" <<EOF
# Generated by run_wsl.sh - edits are overwritten on the next start.
[server]
socket_path = "$SOCKET_PATH"

[media]
database_path = "$DEV_DIR/media.sqlite3"
folders = ["$MEDIA_DIR"]
supported_formats = ["mp3", "flac", "ogg"]
rescan_on_start = true
resume_mode = "restore_paused"
cover_cache_dir = "$DEV_DIR/covers"

[audio]
navigation_interrupt = "pause_music"

[logging]
directory = "$DEV_DIR/logs"
level = "info"

[system]
metrics_interval_seconds = 30
disk_metrics_interval_seconds = 300
disk_paths = []

[navigation]
position_source = "replay"
replay_file = "$REPLAY_FILE"
replay_loop = true
valhalla_url = "http://127.0.0.1:$VALHALLA_PORT"
map_region = "hessen"
names_database = "$NAMES_DATABASE"
EOF

BACKEND_PID=""
TUNNEL_PID=""
cleanup() {
  local pid
  for pid in "$TUNNEL_PID" "$BACKEND_PID"; do
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [[ -S "$SOCKET_PATH" ]] && command -v fuser >/dev/null && fuser "$SOCKET_PATH" >/dev/null 2>&1; then
  echo "[wsl] ERROR: a backend is already listening on $SOCKET_PATH"
  exit 1
fi
rm -f "$SOCKET_PATH"

echo "[wsl] Starting backend (log: $DEV_DIR/logs/backend.log)..."
# The dev shell may export CARNINE_SOCKET_PATH/CARNINE_TCP_ADDRESS; they would
# win over the generated config, so both are dropped for this start.
env -u CARNINE_SOCKET_PATH -u CARNINE_TCP_ADDRESS \
  CARNINE_CONFIG="$DEV_DIR/config.toml" \
  "$BACKEND_DIR/target/debug/carnine-backend" > "$DEV_DIR/logs/backend-stdout.log" 2>&1 &
BACKEND_PID=$!
for _ in $(seq 1 50); do
  [[ -S "$SOCKET_PATH" ]] && break
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo "[wsl] ERROR: backend exited, see $DEV_DIR/logs/backend-stdout.log"
    exit 1
  fi
  sleep 0.2
done
if [[ ! -S "$SOCKET_PATH" ]]; then
  echo "[wsl] ERROR: backend socket did not appear: $SOCKET_PATH"
  exit 1
fi

if [[ -n "$VALHALLA_TUNNEL" ]]; then
  echo "[wsl] Tunnelling Valhalla from $VALHALLA_TUNNEL to 127.0.0.1:$VALHALLA_PORT..."
  ssh -N -o ExitOnForwardFailure=yes -o ConnectTimeout=5 \
    -L "$VALHALLA_PORT:127.0.0.1:$VALHALLA_PORT" "$VALHALLA_TUNNEL" &
  TUNNEL_PID=$!
fi

echo "[wsl] Starting frontend (log: $DEV_DIR/logs/frontend.log)..."
(
  cd "$FRONTEND_BUNDLE"
  env -u CARNINE_TCP_ADDRESS \
    CARNINE_EMBEDDED=1 \
    CARNINE_SOCKET_PATH="$SOCKET_PATH" \
    CARNINE_MAP_TILES="$MAP_TILES" \
    CARNINE_LOG_PATH="$DEV_DIR/logs/frontend.log" \
    LD_LIBRARY_PATH="$FRONTEND_BUNDLE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    ./homescreen -b . -w "$WINDOW_WIDTH" --height "$WINDOW_HEIGHT"
)
