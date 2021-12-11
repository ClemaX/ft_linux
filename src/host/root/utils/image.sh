# Create an empty image of a specific size.
img_new() # dst size
{
	dst="$1"
	size="$2"

	info "Creating empty disk image of size $size MB at $dst..."

	[ -f "$dst" ]&& truncate --size "${size}M" "$dst"

	dd if=/dev/zero of="$dst" iflag=fullblock bs=1M count="$size"

	sync
}

# Create additional devices for a loop device's partitions.
loop_partitions() # dev
{
	dev="$1"

	parts=$(lsblk --raw --output "MAJ:MIN" --noheadings "$dev" | tail -n +2)
	index=1

	for part in $parts
	do
		major="${part%%:*}"
		minor="${part##*:}"

		if [ ! -e "${dev}p${index}" ]
		then
			partdev="${dev}p${index}"
			echo "Creating $partdev..."
			mknod "$partdev" b "$major" "$minor"
		fi

	 	((++index))
	done
}

# Setup a loop device backed by a disk image.
loop_setup() # dev img
{
	dev="$1"
	img="$2"

	if [ ! -e "$dev" ]
	then
		debug "Creating loop device at $dev..."
		mknod "$dev" b 7 0
	fi

	info "Setting up loop device..."
	losetup --partscan "$dev" "$img"

	loop_partitions "$dev"

	debug "Loaded $index partitions!"

	trap "loop_teardown '$dev' $index" EXIT
}

# Tear down a loop device with it's associated partitions.
loop_teardown() # dev partcount
{
	dev="$1"
	partcount=${2:-0}

	i=1

	while [ $i -lt $partcount ]
	do
		partdev="${dev}p${i}"
		info "Removing $partdev..."
		rm -f "$partdev"
		((++i))
	done

	info "Tearing down $dev..."
	losetup -d "$dev"
}
