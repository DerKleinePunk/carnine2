#!/usr/bin/env bash
set -euo pipefail

IMAGE_GZ="${1:?usage: verify-image-ssh.sh IMAGE.img.gz PUBLIC_KEY_FILE}"
PUBLIC_KEY_FILE="${2:?usage: verify-image-ssh.sh IMAGE.img.gz PUBLIC_KEY_FILE}"
ROOTFS_IMAGE="$(mktemp --suffix=.ext4)"
trap 'rm -f "$ROOTFS_IMAGE"' EXIT

[[ -r "$IMAGE_GZ" ]] || { echo "ERROR: image is not readable: $IMAGE_GZ" >&2; exit 1; }
[[ -r "$PUBLIC_KEY_FILE" ]] || { echo "ERROR: public key is not readable: $PUBLIC_KEY_FILE" >&2; exit 1; }
command -v zcat >/dev/null || { echo "ERROR: zcat is required" >&2; exit 1; }
command -v dd >/dev/null || { echo "ERROR: dd is required" >&2; exit 1; }
command -v debugfs >/dev/null || { echo "ERROR: debugfs is required" >&2; exit 1; }

# The recipe starts the root partition at 256 MiB (524288 sectors).
zcat "$IMAGE_GZ" | dd bs=512 skip=524288 of="$ROOTFS_IMAGE" status=none
EXPECTED="$(tr -d '\r\n' < "$PUBLIC_KEY_FILE")"
ACTUAL="$(debugfs -R 'cat /home/pi/.ssh/authorized_keys' "$ROOTFS_IMAGE" 2>/dev/null | tr -d '\r\n')"

if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "ERROR: authorized_keys in image does not match $PUBLIC_KEY_FILE" >&2
  exit 1
fi

echo "SSH authorized_keys verified in $IMAGE_GZ"
