#!/bin/sh

set -eu

STATE_DIR=/var/lib/carnine
PARTITION_STATE="$STATE_DIR/rootfs-partition-expanded"
FILESYSTEM_STATE="$STATE_DIR/rootfs-expanded"

ROOT_PART=$(findmnt -n -o SOURCE /)
ROOT_PARENT=$(lsblk -no PKNAME "$ROOT_PART")

if [ -z "$ROOT_PARENT" ]; then
    echo "Could not determine parent device for root partition $ROOT_PART" >&2
    exit 1
fi

ROOT_DEV="/dev/$ROOT_PARENT"
PART_NUM=${ROOT_PART#"$ROOT_DEV"}
PART_NUM=${PART_NUM#p}
LAST_PART=$(lsblk -nrpo NAME,TYPE "$ROOT_DEV" | awk '$2 == "part" { last = $1 } END { print last }')

if [ "$ROOT_PART" != "$LAST_PART" ]; then
    echo "Root partition $ROOT_PART is not the last partition on $ROOT_DEV" >&2
    exit 1
fi

if [ ! -e "$PARTITION_STATE" ]; then
    printf '%s\n' Yes | parted ---pretend-input-tty "$ROOT_DEV" resizepart "$PART_NUM" 100%
    partprobe "$ROOT_DEV" || true
    udevadm settle
    touch "$PARTITION_STATE"
    systemctl --no-block reboot
    exit 0
fi

if [ ! -e "$FILESYSTEM_STATE" ]; then
    udevadm settle
    resize2fs "$ROOT_PART"
    touch "$FILESYSTEM_STATE"
    systemctl disable expand-rootfs.service
fi
