#!/usr/bin/env bash

set -eEu

SCRIPTDIR=~

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/disk.sh"
source "$SCRIPTDIR/utils/image.sh"
source "$SCRIPTDIR/utils/lfs_chroot.sh"

set +eEu

loop_setup "$IMG_DST"
disk_mount "$LOOP_DEV" "$LFS"

lfs_chroot
