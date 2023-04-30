# shellcheck shell=bash

# TODO: Replace size in MiB with conversion using numfmt

# Create an empty image of a specific size.
img_new() # dst size
{
	local dst="$1"
	local size="$2"

	info "Creating empty disk image of size $size MiB at $dst..."

	[ -f "$dst" ] && rm -fv "$dst"

	fallocate -l "${size}M" "$dst"
}

# Shrink an image to the last allocated sector.
img_shrink() # dst
{
	local dst="$1"

	local disk_sector_size
	local disk_sector_count
	local disk_end_sector
	local size

	disk_sector_size=$(sgdisk -p "$dst" | grep -i '^Sector size' | sed 's/.*:\s*\([[:digit:]]\+\)\s*bytes.*/\1/')
	disk_end_sector=$(partx --raw "$dst" -o End --noheadings --nr -1)

	# Sector indices start at 0 and 33 sectors are needed internally for GPT.
	disk_sector_count=$((disk_end_sector + 1 + 33))
	size=$((disk_sector_count * disk_sector_size))

	info "Shrinking disk image at $dst to $((size / 1000000)) MiB..."

	truncate --size="$size" "$dst"

	# Restore backup partition table.
	sgdisk --move-second-header "$dst"
}

# Create additional devices for a loop device's partitions.
loop_partitions()
{
	local parts
	local part_dev

	parts=$(lsblk "$LOOP_DEV" --output NAME,MAJ:MIN -x NAME --noheadings \
		| tail -n +2 \
		| cut -d' ' -f2)

	LOOP_PARTS=0
	for part in $parts
	do
	 	((++LOOP_PARTS))

		major="${part%%:*}"
		minor="${part##*:}"

		if [ ! -e "${LOOP_DEV}p${LOOP_PARTS}" ]
		then
			part_dev="${LOOP_DEV}p${LOOP_PARTS}"

			debug "Creating $part_dev ($minor:$major)..."
			mknod --mode 660 "$part_dev" b "$major" "$minor"
		fi
	done
}

# Setup a loop device backed by a disk image.
loop_setup() # img
{
	local img="$1"
	local try=3


	if [ -e "$LOOP_DEV" ]
	then
		losetup -d "$LOOP_DEV"
		rm "$LOOP_DEV"
	fi

	debug "Creating loop device at $LOOP_DEV..."
	mknod --mode 660 "$LOOP_DEV" b 7 0

	info "Setting up $LOOP_DEV..."

	until [ "$((try -= 1))" -eq 0 ] || losetup --partscan "$LOOP_DEV" "$img"
	do
		losetup -d "$LOOP_DEV"

		sleep 1

		info "Setting up $LOOP_DEV..."
	done

	[ "$try" -eq 0 ] && false

	loop_partitions

	debug "Loaded $((LOOP_PARTS - 1)) partitions!"
}

# Tear down a loop device with it's associated partitions.
loop_teardown()
{
	local part_dev

	local i=1
	while [ "$i" -le "${LOOP_PARTS:-0}" ]
	do
		part_dev="${LOOP_DEV}p${i}"

		info "Removing $part_dev..."
		rm -f "$part_dev"

		((++i))
	done

	info "Tearing down $LOOP_DEV..."
	losetup -d "$LOOP_DEV"
	rm -vf "$LOOP_DEV"
}
