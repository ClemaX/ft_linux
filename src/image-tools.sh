#!/bin/bash

img_new() # dst size
{
	dst="$1"
	size="$2"
	echo "Creating empty disk image with size $size MB at $dst..."
	dd if=/dev/zero of="$dst" iflag=fullblock bs=1M count="$size"
	sync
}

loop_partitions() # dev
{
	dev="$1"

	parts=$(lsblk --raw --output "MAJ:MIN" --noheadings "$dev" | tail -n +2)
	index=1

	for part in $parts; do
		major="${part%%:*}"
		minor="${part##*:}"
	
		if [ ! -e "${dev}p${index}" ]; then
      partdev="${dev}p${index}"
      echo "Creating $partdev..."
			mknod "$partdev" b "$major" "$minor"
		fi
  
	 	((++index))
	done
}

loop_setup() # dev img
{
	dev="$1"
	img="$2"

	if [ ! -e "$dev" ]; then
		echo "Creating loop device at $dev..."
		mknod "$dev" b 7 0
	fi

  # TODO: Remove this after debug
	losetup -d "$dev" || :

	echo "Setting up loop device..."
	losetup --partscan "$dev" "$img"

	loop_partitions "$dev"

	trap "loop_teardown '$dev' $((index - 1))" EXIT
}

loop_teardown() # dev partcount
{
	dev="$1"
  partcount=$2

  i=1

  # TODO: Remove, this seems unnecessary and broken
  while [ $i -lt $partcount ] ; do
    partdev="${dev}p${i}"
  	echo "Removing $partdev..."
    rm -f "$partdev"
    ((++i))
  done

	echo "Tearing down $dev..."
	losetup -d "$dev"
}
