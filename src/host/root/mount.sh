#!/usr/bin/env bash

set -eEu

SCRIPTDIR=~

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/disk.sh"
source "$SCRIPTDIR/utils/image.sh"

loop_setup "$LOOP_DEV" "$IMG_DST"
disk_mount "$LOOP_DEV" "$LFS"
