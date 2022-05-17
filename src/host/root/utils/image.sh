# shellcheck shell=bash

# Create an empty image of a specific size.
img_new() # dst size
{
	local dst="$1"
	local size="$2"

	info "Creating empty disk image of size $size MiB at $dst..."

	[ -f "$dst" ] && rm -fv "$dst"

	fallocate -l "${size}M" "$dst"
}

# Create additional devices for a loop device's partitions.
loop_partitions()
{
	local parts
	local part_dev

	parts=$(lsblk --raw --output "MAJ:MIN" --noheadings "$LOOP_DEV" | tail -n +2)

	LOOP_PARTS=0
	for part in $parts
	do
	 	((++LOOP_PARTS))

		major="${part%%:*}"
		minor="${part##*:}"

		if [ ! -e "${LOOP_DEV}p${LOOP_PARTS}" ]
		then
			part_dev="${LOOP_DEV}p${LOOP_PARTS}"

			echo "Creating $part_dev..."
			mknod "$part_dev" b "$major" "$minor"
		fi
	done
}

# Setup a loop device backed by a disk image.
loop_setup() # img
{
	local img="$1"
	local try=3


	[ -e "$LOOP_DEV" ] && rm "$LOOP_DEV"

	debug "Creating loop device at $LOOP_DEV..."
	mknod "$LOOP_DEV" b 7 0

	info "Setting up $LOOP_DEV..."
	((try -= 1))

	until [ "$try" -eq 0 ] || losetup --partscan "$LOOP_DEV" "$img"
	do
		[ -e "$LOOP_DEV" ] && rm "$LOOP_DEV"
		sleep 1

		debug "Creating loop device at $LOOP_DEV..."
		mknod "$LOOP_DEV" b 7 0
		sleep 1

		info "Setting up $LOOP_DEV..."
		((try -= 1))
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
