#!/bin/bash

set -euo pipefail

source image-tools.sh

lfs_base_url="https://www.linuxfromscratch.org/lfs/view/$LFS_VERSION"



sources_fetch() # url dst
{
  url="$1"
  dst="$2"

  mkdir -v 
  chmod -v a+wt "$dst"

  # TODO: Replace kernel with latest version 4.X

  wget -O- "$url/wget-list" \
  | wget --input-file=- --continue --directory-prefix="$dst"

  pushd "$dst"
    wget -O- "$url/md5sums" | md5sum -c
  popd
}

img_new "$IMG_DST" "$IMG_SIZE"

loop_setup "$LOOP_DEV" "$IMG_DST"

# n: do not create default partition table
fdisk -n "$LOOP_DEV" << EOF || :
g
n


+200M
n
2


w
EOF

loop_partitions /dev/loop0

mkfs.ext4 -L EFI /dev/loop0p1
mkfs.ext4 -L root /dev/loop0p2

disk_mount "$LOOP_DEV" "$LFS"

sources_fetch "$lfs_base_url" "$LFS/sources"
chown -v lfs "$LFS" "$LFS/sources"
