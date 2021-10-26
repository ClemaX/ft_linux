#!/bin/bash

set -eEu

source ~/utils/disk.sh
source ~/utils/cache.sh
source ~/utils/image.sh
source ~/utils/linux.sh
source ~/utils/sources.sh

lfs_base_url="https://www.linuxfromscratch.org/lfs/view/$LFS_VERSION"

error_handler()
{
  echo "$BASH_SOURCE:$LINENO: $BASH_COMMAND returned with unexpected exit status $?"
}

trap error_handler ERR

img_new "$IMG_DST" "$IMG_SIZE"

loop_setup "$LOOP_DEV" "$IMG_DST"

disk_partition "$LOOP_DEV"

loop_partitions "$LOOP_DEV"

mkfs.ext4 -L EFI "${LOOP_DEV}p1"
mkfs.ext4 -L root "${LOOP_DEV}p2"

disk_mount "$LOOP_DEV" "$LFS"

# Make files readable by anyone
umask 022
sources_fetch "$lfs_base_url" "$LFS/sources"
chown -v lfs "$LFS" "$LFS/sources"

pushd "$LFS"
  env -i LFS="$LFS" BASH_ENV='~/.bashrc' su lfs -c "~/build.sh"
popd
