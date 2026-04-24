#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/src/backend"
FRONTEND_DIR="$ROOT_DIR/src/frontend"
LOG_DIR="$ROOT_DIR/build-logs"

BUILD_MODE="debug"
if [[ "${1:-}" == "--release" ]]; then
  BUILD_MODE="release"
fi

mkdir -p "$LOG_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/linux-${BUILD_MODE}-${TIMESTAMP}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[linux] Log file: $LOG_FILE"

echo "[linux] Building backend (native x86_64, release)..."
(
  cd "$BACKEND_DIR"
  cargo build --release
)

echo "[linux] Preparing frontend dependencies..."
(
  cd "$FRONTEND_DIR"
  flutter pub get
)

if [[ ! -d "$FRONTEND_DIR/linux" ]]; then
  echo "[linux] No linux platform folder found. Bootstrapping linux platform files..."
  (
    cd "$FRONTEND_DIR"
    flutter config --enable-linux-desktop
    flutter create --platforms=linux .
  )
fi

echo "[linux] Building Flutter Linux app ($BUILD_MODE)..."
(
  cd "$FRONTEND_DIR"
  if [[ "$BUILD_MODE" == "release" ]]; then
    flutter build linux --release
  else
    flutter build linux --debug
  fi
)

echo
echo "[linux] Build finished."
echo "[linux] Backend binary: $BACKEND_DIR/target/release/carnine-backend"
if [[ "$BUILD_MODE" == "release" ]]; then
  echo "[linux] Frontend bundle: $FRONTEND_DIR/build/linux/x64/release/bundle"
else
  echo "[linux] Frontend bundle: $FRONTEND_DIR/build/linux/x64/debug/bundle"
fi
echo "[linux] Full log: $LOG_FILE"
