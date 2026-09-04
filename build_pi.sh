#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/src/backend"
FRONTEND_DIR="$ROOT_DIR/src/frontend"
PROTO_DIR="$ROOT_DIR/src/proto"
LOG_DIR="$ROOT_DIR/build-logs"

mkdir -p "$LOG_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/pi-${TIMESTAMP}.log"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[pi] Log file: $LOG_FILE"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[pi] ERROR: Invalid VERSION: $VERSION"
  exit 1
fi
echo "[pi] Building Carnine version $VERSION"

if ! command -v flutterpi_tool >/dev/null 2>&1; then
  echo "[pi] ERROR: flutterpi_tool not found in PATH."
  echo "[pi] Hint: export PATH=\"$PATH:$HOME/.pub-cache/bin\""
  exit 1
fi

echo "[pi] Building backend (aarch64-unknown-linux-gnu, release)..."
(
  cd "$BACKEND_DIR"
  CARNINE_VERSION="$VERSION" cargo build --release --target aarch64-unknown-linux-gnu
  rm -f target/debian/carnine-backend_*_arm64.deb
  rm -f target/aarch64-unknown-linux-gnu/debian/carnine-backend_*_arm64.deb
  CARNINE_VERSION="$VERSION" cargo deb --target aarch64-unknown-linux-gnu --deb-version "$VERSION"
)

shopt -s nullglob
BACKEND_PACKAGES=(
  "$BACKEND_DIR/target/debian/"carnine-backend_*_arm64.deb
  "$BACKEND_DIR/target/aarch64-unknown-linux-gnu/debian/"carnine-backend_*_arm64.deb
)
if [[ "${#BACKEND_PACKAGES[@]}" -ne 1 ]]; then
  if [[ "${#BACKEND_PACKAGES[@]}" -eq 0 ]]; then
    echo "[pi] ERROR: No ARM64 backend package found"
    exit 1
  fi

  BACKEND_CHECKSUM="$(sha256sum "${BACKEND_PACKAGES[0]}" | awk '{print $1}')"
  for candidate in "${BACKEND_PACKAGES[@]:1}"; do
    candidate_checksum="$(sha256sum "$candidate" | awk '{print $1}')"
    if [[ "$candidate_checksum" != "$BACKEND_CHECKSUM" ]]; then
      echo "[pi] ERROR: Multiple different ARM64 backend packages found"
      exit 1
    fi
  done
  echo "[pi] Multiple identical ARM64 backend packages found; using ${BACKEND_PACKAGES[0]}"
fi
BACKEND_PACKAGE="${BACKEND_PACKAGES[0]}"
if [[ "$(dpkg-deb -f "$BACKEND_PACKAGE" Architecture)" != "arm64" ]]; then
  echo "[pi] ERROR: Backend package is not arm64: $BACKEND_PACKAGE"
  exit 1
fi
cp "$BACKEND_PACKAGE" "$ROOT_DIR/resources/debos/carnine-backend.deb"
echo "[pi] Backend package staged: $ROOT_DIR/resources/debos/carnine-backend.deb"

echo "[pi] Preparing frontend dependencies..."
(
  cd "$FRONTEND_DIR"
  flutter pub get
)

if ! command -v protoc >/dev/null 2>&1; then
  echo "[pi] ERROR: protoc not found in PATH."
  echo "[pi] Hint: install protobuf compiler (e.g. sudo apt install protobuf-compiler)."
  exit 1
fi

if ! command -v protoc-gen-dart >/dev/null 2>&1; then
  echo "[pi] ERROR: protoc-gen-dart not found in PATH."
  echo "[pi] Hint: dart pub global activate protoc_plugin"
  exit 1
fi

echo "[pi] Generating shared protobuf Dart stubs..."
(
  cd "$FRONTEND_DIR"
  protoc -I "$PROTO_DIR" --dart_out=grpc:lib/lib "$PROTO_DIR/carnine.proto"
)

echo "[pi] Building Flutter-Pi bundle (arm64 / pi4)..."
(
  cd "$FRONTEND_DIR"
  flutterpi_tool build --arch=arm64 --cpu=pi4 --dart-define="CARNINE_VERSION=$VERSION"
)

FRONTEND_BUNDLE="$FRONTEND_DIR/build/flutter-pi/aarch64-generic"
FRONTEND_PACKAGE="$ROOT_DIR/resources/debos/carnine-frontend.deb"
if [[ ! -x "$FRONTEND_BUNDLE/flutter-pi" ]]; then
  echo "[pi] ERROR: Flutter-Pi runtime not found in $FRONTEND_BUNDLE"
  exit 1
fi
"$FRONTEND_DIR/package-deb.sh" "$FRONTEND_BUNDLE" "$FRONTEND_PACKAGE" "$VERSION"
if [[ "$(dpkg-deb -f "$FRONTEND_PACKAGE" Architecture)" != "arm64" ]]; then
  echo "[pi] ERROR: Frontend package is not arm64: $FRONTEND_PACKAGE"
  exit 1
fi
echo "[pi] Frontend package staged: $FRONTEND_PACKAGE"

echo
echo "[pi] Build finished."
echo "[pi] Backend binary: $BACKEND_DIR/target/aarch64-unknown-linux-gnu/release/carnine-backend"
echo "[pi] Frontend bundle: $FRONTEND_BUNDLE"
echo "[pi] Frontend package: $FRONTEND_PACKAGE"
echo "[pi] Full log: $LOG_FILE"
