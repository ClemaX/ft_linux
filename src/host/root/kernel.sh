#!/usr/bin/env bash

set -eEu

SCRIPTDIR=~

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/disk.sh"
source "$SCRIPTDIR/utils/image.sh"
source "$SCRIPTDIR/utils/lfs_chroot.sh"

ACTION="$1"

loop_setup "$IMG_DST"
disk_mount "$LOOP_DEV" "$LFS"

export DEV_SWAP_ID
DEV_SWAP_ID="PARTUUID=$(blkid "${LOOP_DEV}p2" -o value -s PARTUUID)"

lfs_chroot "$LFS" /build/configure_kernel.sh "$ACTION"
