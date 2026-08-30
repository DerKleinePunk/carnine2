#!/bin/sh

set -eu

STATE_DIR=/var/lib/carnine
PARTITION_STATE="$STATE_DIR/rootfs-partition-expanded"
FILESYSTEM_STATE="$STATE_DIR/rootfs-expanded"

ROOT_PART=$(findmnt -n -o SOURCE /)
ROOT_DEV="/dev/$(lsblk -no PKNAME "$ROOT_PART")"
PART_NUM=$(lsblk -no NAME "$ROOT_PART" | sed -E 's/.*p?([0-9]+)$/\1/')
LAST_PART_NAME=$(lsblk -nrpo NAME,TYPE "$ROOT_DEV" | awk '$2 == "part" { last = $1 } END { print last }')
LAST_PART_NUM=$(printf '%s\n' "$LAST_PART_NAME" | sed -E 's/.*p?([0-9]+)$/\1/')

if [ "$PART_NUM" != "$LAST_PART_NUM" ]; then
    echo "Root partition $ROOT_PART is not the last partition on $ROOT_DEV" >&2
    exit 1
fi

if [ ! -e "$PARTITION_STATE" ]; then
    parted -s "$ROOT_DEV" resizepart "$PART_NUM" 100%
    partprobe "$ROOT_DEV" || true
    touch "$PARTITION_STATE"
    systemctl --no-block reboot
    exit 0
fi

if [ ! -e "$FILESYSTEM_STATE" ]; then
    resize2fs "$ROOT_PART"
    touch "$FILESYSTEM_STATE"
    systemctl disable expand-rootfs.service
fi
