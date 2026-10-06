#!/usr/bin/env bash
set -euo pipefail

# Packages the offline voice for spoken turn announcements as carnine-voice.deb:
# sherpa-onnx's C API with ONNX Runtime (arm64) and the German Piper voices
# thorsten-medium and thorsten-low (CC0). The backend loads them at run time.
#
#   package-deb.sh <output-deb> [download-dir]
#
# Downloads the release files once into download-dir (build/voice-downloads by
# default) and checks them against the hashes below before packaging.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DEB="${1:?Usage: package-deb.sh <output-deb> [download-dir]}"
DOWNLOADS="${2:-$ROOT_DIR/../../build/voice-downloads}"
RELEASES=https://github.com/k2-fsa/sherpa-onnx/releases/download
LIBRARY=sherpa-onnx-v1.13.8-linux-aarch64-shared-cpu-lib
# name  url-path  sha256
FILES=(
  "$LIBRARY.tar.bz2 v1.13.8/$LIBRARY.tar.bz2 fb98b80628a383909bf83626daca2e0d0ffc93bf1f7d222eaaa4282b388f072f"
  "vits-piper-de_DE-thorsten-medium.tar.bz2 tts-models/vits-piper-de_DE-thorsten-medium.tar.bz2 50487d9c95fdf2191f31d2588569381063ba1591dcd4c7d4bdd30f12b2191714"
  "vits-piper-de_DE-thorsten-low.tar.bz2 tts-models/vits-piper-de_DE-thorsten-low.tar.bz2 41fab35910fdcec4696b031951d8fd6c262e594cf77b35e1068fadbeb5a091a6"
)

install -d "$DOWNLOADS"
for entry in "${FILES[@]}"; do
  read -r name path hash <<<"$entry"
  if [[ ! -f "$DOWNLOADS/$name" ]]; then
    curl -fsSL -o "$DOWNLOADS/$name.part" "$RELEASES/$path"
    mv "$DOWNLOADS/$name.part" "$DOWNLOADS/$name"
  fi
  echo "$hash  $DOWNLOADS/$name" | sha256sum -c --quiet - \
    || { echo "ERROR: $name does not match its pinned hash" >&2; exit 1; }
done

PACKAGE_ROOT="$(mktemp -d)"
UNPACK="$(mktemp -d)"
trap 'rm -rf "$PACKAGE_ROOT" "$UNPACK"' EXIT
# mktemp creates it 0700, and it becomes the "./" entry of the package.
chmod 0755 "$PACKAGE_ROOT"
for entry in "${FILES[@]}"; do
  read -r name _ _ <<<"$entry"
  tar xjf "$DOWNLOADS/$name" -C "$UNPACK"
done

LIB_DIR="$PACKAGE_ROOT/usr/lib/carnine/voice"
VOICES="$PACKAGE_ROOT/usr/share/carnine/voices"
install -d "$PACKAGE_ROOT/DEBIAN" "$LIB_DIR" "$VOICES" "$PACKAGE_ROOT/usr/share/doc/carnine-voice"
install -m 0644 "$UNPACK/$LIBRARY"/lib/*.so "$LIB_DIR/"
for library in "$LIB_DIR"/*.so; do
  if [[ "$(file -b "$library")" != *"ARM aarch64"* ]]; then
    echo "ERROR: $library is not an arm64 library" >&2
    exit 1
  fi
done

# Both voices come with the same espeak-ng-data (19 MB); it is packaged once
# and each voice links to it.
for voice in medium low; do
  source_dir="$UNPACK/vits-piper-de_DE-thorsten-$voice"
  target="$VOICES/thorsten-$voice"
  install -d "$target"
  install -m 0644 "$source_dir"/*.onnx "$source_dir"/*.onnx.json "$source_dir/tokens.txt" \
    "$source_dir/MODEL_CARD" "$target/"
  if [[ ! -d "$VOICES/espeak-ng-data" ]]; then
    cp -r "$source_dir/espeak-ng-data" "$VOICES/espeak-ng-data"
  elif ! diff -rq "$source_dir/espeak-ng-data" "$VOICES/espeak-ng-data" >/dev/null; then
    echo "ERROR: the voices bring different espeak-ng-data" >&2
    exit 1
  fi
  ln -s ../espeak-ng-data "$target/espeak-ng-data"
done
find "$VOICES" -type d -exec chmod 0755 {} +
find "$VOICES" -type f -exec chmod 0644 {} +

cp "$ROOT_DIR/debian/control" "$PACKAGE_ROOT/DEBIAN/control"
install -m 0644 "$ROOT_DIR/debian/copyright" "$PACKAGE_ROOT/usr/share/doc/carnine-voice/copyright"
install -d "$(dirname "$OUTPUT_DEB")"
rm -f "$OUTPUT_DEB"
dpkg-deb --build --root-owner-group -Zxz "$PACKAGE_ROOT" "$OUTPUT_DEB"
