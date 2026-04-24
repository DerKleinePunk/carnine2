#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/src/backend"
FRONTEND_DIR="$ROOT_DIR/src/frontend"
LOG_DIR="$ROOT_DIR/build-logs"

mkdir -p "$LOG_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/pi-${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[pi] Log file: $LOG_FILE"

if ! command -v flutterpi_tool >/dev/null 2>&1; then
  echo "[pi] ERROR: flutterpi_tool not found in PATH."
  echo "[pi] Hint: export PATH=\"$PATH:$HOME/.pub-cache/bin\""
  exit 1
fi

echo "[pi] Building backend (aarch64-unknown-linux-gnu, release)..."
(
  cd "$BACKEND_DIR"
  cargo build --release --target aarch64-unknown-linux-gnu
)

echo "[pi] Preparing frontend dependencies..."
(
  cd "$FRONTEND_DIR"
  flutter pub get
)

echo "[pi] Building Flutter-Pi bundle (arm64 / pi4)..."
(
  cd "$FRONTEND_DIR"
  flutterpi_tool build --arch=arm64 --cpu=pi4
)

echo
echo "[pi] Build finished."
echo "[pi] Backend binary: $BACKEND_DIR/target/aarch64-unknown-linux-gnu/release/carnine-backend"
echo "[pi] Frontend bundle: $FRONTEND_DIR/build/flutter-pi/aarch64-generic"
echo "[pi] Full log: $LOG_FILE"
