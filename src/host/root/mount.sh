#!/usr/bin/env bash

set -eEu

source ~/utils/logger.sh
source ~/utils/disk.sh
source ~/utils/image.sh

loop_setup "$LOOP_DEV" "$IMG_DST"
disk_mount "$LOOP_DEV" "$LFS"
