#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/src/backend"
FRONTEND_DIR="$ROOT_DIR/src/frontend"
PROTO_DIR="$ROOT_DIR/src/proto"
LOG_DIR="$ROOT_DIR/build-logs"
SYSROOT="${CARNINE_ARM64_SYSROOT:-$ROOT_DIR/build/sysroots/carnine-pi-arm64}"
# The frontend is cross-built with emb_cli and runs under ivi-homescreen. The
# workspace holds the Flutter SDK emb pins and the ivi-homescreen checkout;
# see docs/07-deployment.md for how to provision it.
EMB_WORKSPACE="${CARNINE_EMB_WORKSPACE:-$HOME/develop/emb-workspace}"
EMB_EMBEDDER_DIR="$EMB_WORKSPACE/app/ivi-homescreen"
EMB_TARGET="${CARNINE_EMB_TARGET:-rpi4-trixie}"
EMB_BACKEND="drm-kms-egl"
FLUTTER_BIN="$EMB_WORKSPACE/flutter/bin/flutter"
# emb builds the app in place and leaves files behind (analysis_options.yaml,
# pubspec.lock, libapp.so), so it gets a copy of the frontend, not the tree.
FRONTEND_STAGING_DIR="$ROOT_DIR/build/emb-app/carnine_frontend"
FRONTEND_BUILD_MODE="${CARNINE_FRONTEND_BUILD_MODE:-release}"
case "$FRONTEND_BUILD_MODE" in
  release|profile|debug) ;;
  *)
    echo "[pi] ERROR: Invalid CARNINE_FRONTEND_BUILD_MODE: $FRONTEND_BUILD_MODE (expected release, profile or debug)"
    exit 1
    ;;
esac

mkdir -p "$LOG_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/pi-${TIMESTAMP}.log"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
GIT_HASH="$(git -C "$ROOT_DIR" rev-parse --short=12 HEAD)"
BUILD_TIMESTAMP="$(date -u +%Y%m%d%H%M%S)"
BUILD_VERSION="${VERSION}+git${BUILD_TIMESTAMP}.${GIT_HASH}"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[pi] Log file: $LOG_FILE"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "[pi] ERROR: Invalid VERSION: $VERSION"
  exit 1
fi
echo "[pi] Building Carnine version $VERSION"
echo "[pi] Build version: $BUILD_VERSION"

if [[ ! -f "$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig/alsa.pc" ]]; then
  echo "[pi] ERROR: ARM64 sysroot is missing or incomplete: $SYSROOT"
  echo "[pi] Hint: synchronize the Pi development sysroot into build/sysroots/carnine-pi-arm64."
  exit 1
fi

if ! command -v emb >/dev/null 2>&1; then
  echo "[pi] ERROR: emb not found in PATH."
  echo "[pi] Hint: dart install emb_cli"
  exit 1
fi

if [[ ! -x "$FLUTTER_BIN" || ! -f "$EMB_EMBEDDER_DIR/.emb/raspberry-pi.emb.yaml" ]]; then
  echo "[pi] ERROR: emb workspace is missing or incomplete: $EMB_WORKSPACE"
  echo "[pi] Hint: set CARNINE_EMB_WORKSPACE or provision it as described in docs/07-deployment.md."
  exit 1
fi

echo "[pi] Building backend (aarch64-unknown-linux-gnu, release)..."
(
  cd "$BACKEND_DIR"
  PKG_CONFIG_ALLOW_CROSS=1 \
  PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
  PKG_CONFIG_PATH="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig" \
  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
  CARNINE_VERSION="$VERSION" CARNINE_BUILD_ID="$BUILD_VERSION" cargo build --release --target aarch64-unknown-linux-gnu
  rm -f target/debian/carnine-backend_*_arm64.deb
  rm -f target/aarch64-unknown-linux-gnu/debian/carnine-backend_*_arm64.deb
  PKG_CONFIG_ALLOW_CROSS=1 \
  PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
  PKG_CONFIG_PATH="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig" \
  CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
  CARNINE_VERSION="$VERSION" CARNINE_BUILD_ID="$BUILD_VERSION" cargo deb --target aarch64-unknown-linux-gnu --deb-version "$BUILD_VERSION"
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

echo "[pi] Staging frontend for emb: $FRONTEND_STAGING_DIR"
mkdir -p "$FRONTEND_STAGING_DIR"
rsync -a --delete \
  --exclude=/build/ --exclude=/.dart_tool/ \
  --exclude='/libapp.so*' --exclude='*.symbols' --exclude='obfuscation_map*' \
  "$FRONTEND_DIR/" "$FRONTEND_STAGING_DIR/"

# emb's AOT step has no --dart-define, so the version goes into the staged copy
# as the String.fromEnvironment default. build_linux.sh still uses dart-defines.
sed -i \
  -e "s/defaultValue: 'unknown',/defaultValue: '$VERSION',/" \
  -e "s/defaultValue: _carnineVersion,/defaultValue: '$BUILD_VERSION',/" \
  "$FRONTEND_STAGING_DIR/lib/main.dart"
if ! grep -q "defaultValue: '$BUILD_VERSION'," "$FRONTEND_STAGING_DIR/lib/main.dart"; then
  echo "[pi] ERROR: Could not stamp the build version into the staged lib/main.dart"
  exit 1
fi

echo "[pi] Preparing frontend dependencies..."
(
  cd "$FRONTEND_STAGING_DIR"
  "$FLUTTER_BIN" pub get
)

echo "[pi] Building ivi-homescreen bundle ($EMB_TARGET / $EMB_BACKEND, $FRONTEND_BUILD_MODE)..."
EMB_LOG="$LOG_DIR/pi-${TIMESTAMP}-emb.log"
(
  cd "$EMB_EMBEDDER_DIR"
  # Plugins stay off: the frontend uses no native plugin on the Pi
  # (window_manager is desktop-only and skipped under CARNINE_EMBEDDED).
  emb cross . --target "$EMB_TARGET" --build --backend "$EMB_BACKEND" \
    --app "$FRONTEND_STAGING_DIR" --mode "$FRONTEND_BUILD_MODE" \
    -D DISABLE_PLUGINS=ON \
    -w "$EMB_WORKSPACE"
) 2>&1 | tee "$EMB_LOG"

# The bundle path carries a hash over the defines, so it is taken from emb's
# own report rather than predicted.
FRONTEND_BUNDLE="$(sed -n "s/^.*$EMB_BACKEND: runnable → \([^[:space:]]*\).*/\1/p" "$EMB_LOG" | tail -n 1)"
FRONTEND_PACKAGE="$ROOT_DIR/resources/debos/carnine-frontend.deb"
if [[ -z "$FRONTEND_BUNDLE" || ! -x "$FRONTEND_BUNDLE/homescreen" ]]; then
  echo "[pi] ERROR: ivi-homescreen bundle not found (emb log: $EMB_LOG)"
  exit 1
fi
"$FRONTEND_DIR/package-deb.sh" "$FRONTEND_BUNDLE" "$FRONTEND_PACKAGE" "$BUILD_VERSION"
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
