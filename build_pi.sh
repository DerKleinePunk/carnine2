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
# Set to 1 once after a new emb version (or a changed emb call): emb then
# re-pins emb.lock instead of stopping with "emb.lock drift". It has to be
# this very call, a separate --fetch-only pins other inputs.
EMB_LOCK_ARGS=()
if [[ "${CARNINE_EMB_UPDATE_LOCK:-0}" == "1" ]]; then
  EMB_LOCK_ARGS=(--update-lock)
fi
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

# The package carries the licence texts of all crates in the binary (#123).
if ! command -v cargo-about >/dev/null 2>&1; then
  echo "[pi] ERROR: cargo-about not found."
  echo "[pi] Hint: cargo install cargo-about --locked --features cli"
  exit 1
fi

# With cargo-auditable the binary carries its dependency list, so the SBOM
# of the package names the crates actually built in (#41). Without it the
# build still works; the package SBOM then lacks the crates.
if command -v cargo-auditable >/dev/null 2>&1; then
  BACKEND_BUILD=(cargo auditable build)
else
  BACKEND_BUILD=(cargo build)
  echo "[pi] WARNING: cargo-auditable not found, the package SBOM will lack the crates."
  echo "[pi] Hint: cargo install cargo-auditable --locked"
fi

echo "[pi] Building backend (aarch64-unknown-linux-gnu, release)..."
(
  cd "$BACKEND_DIR"
  export PKG_CONFIG_ALLOW_CROSS=1
  export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
  export PKG_CONFIG_PATH="$SYSROOT/usr/lib/aarch64-linux-gnu/pkgconfig"
  export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
  export CARNINE_VERSION="$VERSION" CARNINE_BUILD_ID="$BUILD_VERSION"
  "${BACKEND_BUILD[@]}" --release --target aarch64-unknown-linux-gnu
  rm -f target/debian/carnine-backend_*_arm64.deb
  rm -f target/aarch64-unknown-linux-gnu/debian/carnine-backend_*_arm64.deb
  rm -f target/third-party-licenses.txt
  # Stops on a licence about.toml does not accept.
  cargo about generate --offline --fail --target aarch64-unknown-linux-gnu \
    about.hbs -o target/third-party-licenses.txt
  # --no-build: cargo-deb would build again, without the dependency list.
  cargo deb --no-build --target aarch64-unknown-linux-gnu --deb-version "$BUILD_VERSION"
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
# cargo-deb writes no DEBIAN/md5sums; without them dpkg -V notices nothing.
sh "$ROOT_DIR/resources/tools/deb/md5sums.sh" "$ROOT_DIR/resources/debos/carnine-backend.deb"
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
  # Plugins stay off: the frontend uses no ivi-homescreen plugin on the Pi
  # (window_manager is desktop-only and skipped under CARNINE_EMBEDDED); the
  # camera view is built on its own below.
  emb cross . --target "$EMB_TARGET" --build --backend "$EMB_BACKEND" \
    --app "$FRONTEND_STAGING_DIR" --mode "$FRONTEND_BUILD_MODE" \
    -D DISABLE_PLUGINS=ON \
    -w "$EMB_WORKSPACE" ${EMB_LOCK_ARGS[@]+"${EMB_LOCK_ARGS[@]}"}
) 2>&1 | tee "$EMB_LOG"

# The bundle path carries a hash over the defines, so it is taken from emb's
# own report rather than predicted.
FRONTEND_BUNDLE="$(sed -n "s/^.*$EMB_BACKEND: runnable → \([^[:space:]]*\).*/\1/p" "$EMB_LOG" | tail -n 1)"
FRONTEND_PACKAGE="$ROOT_DIR/resources/debos/carnine-frontend.deb"
if [[ -z "$FRONTEND_BUNDLE" || ! -x "$FRONTEND_BUNDLE/homescreen" ]]; then
  echo "[pi] ERROR: ivi-homescreen bundle not found (emb log: $EMB_LOG)"
  exit 1
fi
# The camera page's platform view (package video_grabber) is no ivi-homescreen
# plugin in the tree, so emb leaves its native part out. It is built here
# against the very shell build emb used for this bundle, so that it matches
# libihs_shared.so.1, and lands in the bundle's lib/, which carnine-frontend
# puts on LD_LIBRARY_PATH.
VIDEO_GRABBER_SOURCE="$(python3 -c '
import json, sys, urllib.parse
packages = json.load(open(sys.argv[1]))["packages"]
uri = next(p["rootUri"] for p in packages if p["name"] == "video_grabber")
print(urllib.parse.urlparse(uri).path.rstrip("/"))
' "$FRONTEND_STAGING_DIR/.dart_tool/package_config.json")"
EMB_TOOLCHAIN="$(sed -n 's/^[[:space:]]*cmake tc file[[:space:]]*:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$EMB_LOG" | tail -n 1)"
IHS_BUILD_DIR="$(dirname "$FRONTEND_BUNDLE")/build-$EMB_BACKEND"
if [[ ! -f "$VIDEO_GRABBER_SOURCE/native/CMakeLists.txt" || ! -f "$EMB_TOOLCHAIN" ||
  ! -f "$IHS_BUILD_DIR/shell/lib/libihs_shared.so" ]]; then
  echo "[pi] ERROR: cannot build the video grabber view (source: $VIDEO_GRABBER_SOURCE," \
    "toolchain: $EMB_TOOLCHAIN, shell build: $IHS_BUILD_DIR)"
  exit 1
fi
VIDEO_GRABBER_BUILD="$ROOT_DIR/build/video_grabber-pi"
VIDEO_GRABBER_LOG="$LOG_DIR/pi-${TIMESTAMP}-video-grabber.log"
echo "[pi] Building the video grabber view from $VIDEO_GRABBER_SOURCE..."
rm -rf "$VIDEO_GRABBER_BUILD"
cmake -S "$VIDEO_GRABBER_SOURCE/native" -B "$VIDEO_GRABBER_BUILD" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
  -DCMAKE_TOOLCHAIN_FILE="$EMB_TOOLCHAIN" \
  -DIHS_BUILD_DIR="$IHS_BUILD_DIR" \
  -DIHS_SOURCE_DIR="$EMB_EMBEDDER_DIR" > "$VIDEO_GRABBER_LOG" 2>&1
cmake --build "$VIDEO_GRABBER_BUILD" >> "$VIDEO_GRABBER_LOG" 2>&1
if [[ "$(file -b "$VIDEO_GRABBER_BUILD/libvideo_grabber_view.so" 2>/dev/null)" != *"ARM aarch64"* ]]; then
  echo "[pi] ERROR: libvideo_grabber_view.so is missing or not arm64 (log: $VIDEO_GRABBER_LOG)"
  exit 1
fi
install -m 0644 "$VIDEO_GRABBER_BUILD/libvideo_grabber_view.so" "$FRONTEND_BUNDLE/lib/"

# Licence texts of ivi-homescreen and its submodules for the package (#123).
IHS_LICENSES="$ROOT_DIR/build/ivi-homescreen-licenses.txt"
rm -f "$IHS_LICENSES"
python3 -I "$ROOT_DIR/resources/tools/sbom/gen_sbom.py" --repo-root "$EMB_EMBEDDER_DIR" \
  --licenses-output "$IHS_LICENSES"
"$FRONTEND_DIR/package-deb.sh" "$FRONTEND_BUNDLE" "$FRONTEND_PACKAGE" "$BUILD_VERSION" "$IHS_LICENSES"
# The listing is read whole first: grep -q stops reading at the match,
# dpkg-deb then dies of SIGPIPE and pipefail fails the check.
FRONTEND_CONTENTS="$(dpkg-deb -c "$FRONTEND_PACKAGE")"
if ! grep -q ' \./opt/carnine/frontend/lib/libvideo_grabber_view\.so$' <<< "$FRONTEND_CONTENTS"; then
  echo "[pi] ERROR: the frontend package lacks libvideo_grabber_view.so"
  exit 1
fi
if [[ "$(dpkg-deb -f "$FRONTEND_PACKAGE" Architecture)" != "arm64" ]]; then
  echo "[pi] ERROR: Frontend package is not arm64: $FRONTEND_PACKAGE"
  exit 1
fi
echo "[pi] Frontend package staged: $FRONTEND_PACKAGE"

# SBOM and CVE report per package, next to it (#41). Only a report: a deploy
# to the test device must not hang on a CVE. The backend SBOM comes from the
# unpacked package (the crates via cargo-auditable), the frontend's from the
# pubspec.lock it was built with - the Dart code is compiled into libapp.so,
# where syft cannot see it. ivi-homescreen vendors its C++ dependencies as git
# submodules without package metadata; resources/tools/sbom/gen_sbom.py reads
# them from the checkout, with CPEs and a VEX document grype gets with --vex.
# Not covered: the Flutter engine.
SYFT="${CARNINE_SYFT:-syft}"
GRYPE="${CARNINE_GRYPE:-grype}"
package_sbom() {
  local name="$1" source="$2" out="$ROOT_DIR/resources/debos/$1"
  "$SYFT" scan "dir:$source" -q --source-name "$name" --source-version "$BUILD_VERSION" \
    -o cyclonedx-json="$out.cdx.json" -o spdx-json="$out.spdx.json"
  if "$GRYPE" "sbom:$out.cdx.json" -q -c "$ROOT_DIR/.grype.yaml" -o table > "$out.grype.txt" 2>&1; then
    echo "[pi] $name: SBOM $out.cdx.json, CVE report $out.grype.txt ($(grep -c . "$out.grype.txt") lines)"
  else
    echo "[pi] WARNING: grype failed for $name, see $out.grype.txt"
  fi
}
if command -v "$SYFT" >/dev/null 2>&1 && command -v "$GRYPE" >/dev/null 2>&1; then
  echo "[pi] Writing package SBOMs and CVE reports..."
  BACKEND_UNPACKED="$(mktemp -d)"
  dpkg-deb -x "$ROOT_DIR/resources/debos/carnine-backend.deb" "$BACKEND_UNPACKED"
  package_sbom carnine-backend "$BACKEND_UNPACKED"
  rm -rf "$BACKEND_UNPACKED"
  package_sbom carnine-frontend "$FRONTEND_STAGING_DIR"
  IHS_OUT="$ROOT_DIR/resources/debos/carnine-frontend-ivi-homescreen"
  # Gone first, so a failed run leaves no report of an earlier build behind.
  rm -f "$IHS_OUT.cdx.json" "$IHS_OUT.openvex.json" "$IHS_OUT.grype.txt"
  if python3 -I "$ROOT_DIR/resources/tools/sbom/gen_sbom.py" --repo-root "$EMB_EMBEDDER_DIR" \
      --output "$IHS_OUT.cdx.json" --vex-output "$IHS_OUT.openvex.json" &&
    "$GRYPE" "sbom:$IHS_OUT.cdx.json" --vex "$IHS_OUT.openvex.json" -q -c "$ROOT_DIR/.grype.yaml" \
      -o table > "$IHS_OUT.grype.txt" 2>&1; then
    echo "[pi] ivi-homescreen: SBOM $IHS_OUT.cdx.json, VEX $IHS_OUT.openvex.json, CVE report $IHS_OUT.grype.txt ($(grep -c . "$IHS_OUT.grype.txt") lines)"
  else
    echo "[pi] WARNING: no ivi-homescreen SBOM or CVE report, see the lines above (and $IHS_OUT.grype.txt if it exists)"
  fi
else
  echo "[pi] WARNING: syft or grype not found, no package SBOM (set CARNINE_SYFT/CARNINE_GRYPE)."
fi

echo
echo "[pi] Build finished."
echo "[pi] Backend binary: $BACKEND_DIR/target/aarch64-unknown-linux-gnu/release/carnine-backend"
echo "[pi] Frontend bundle: $FRONTEND_BUNDLE"
echo "[pi] Frontend package: $FRONTEND_PACKAGE"
echo "[pi] Full log: $LOG_FILE"
