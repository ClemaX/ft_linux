#!/bin/bash

IMG_DST=/dist/disk.img
IMG_SIZE=1000

LOOP_DEV="/dev/loop0"

set -euo pipefail

source image-tools.sh

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

bash
