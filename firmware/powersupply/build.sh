#!/usr/bin/env bash
set -euo pipefail

# Builds the power supply firmware into build/ (RaspberryPower.bin for the
# Windows flashing tool, .hex for avrdude). Uses the installed avr-gcc, or a
# Debian container with gcc-avr when there is none:
#
#   ./build.sh            # build
#   ./build.sh clean      # remove build/
#
# CONTAINER_TOOL picks the container runtime (default: podman, then docker).
# With podman-remote the directory must be visible to the podman machine,
# which for this repository under /mnt/wsl it is.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="docker.io/library/debian:trixie-slim"

if command -v avr-gcc >/dev/null 2>&1; then
  exec make -C "$DIR" "$@"
fi

tool="${CONTAINER_TOOL:-}"
if [[ -z "$tool" ]]; then
  for candidate in podman podman-remote-static-linux_amd64 docker; do
    if command -v "$candidate" >/dev/null 2>&1; then
      tool="$candidate"
      break
    fi
  done
fi
if [[ -z "$tool" ]]; then
  echo "ERROR: neither avr-gcc nor a container runtime found." >&2
  echo "Install: sudo apt install gcc-avr avr-libc binutils-avr make" >&2
  exit 1
fi

echo "avr-gcc not installed, building in $IMAGE with $tool"
"$tool" run --rm -v "$DIR:/src" -w /src "$IMAGE" sh -c "
  set -e
  apt-get update -qq >/dev/null
  apt-get install -y -qq --no-install-recommends gcc-avr avr-libc binutils-avr make >/dev/null
  make $* && chown -R $(id -u):$(id -g) build 2>/dev/null || true
"
