# shellcheck shell=bash

disk_mount() # dev mnt
{
	local dev="$1"
	local mnt="$2"

	mkdir -pv "$mnt"
	mount -v -t ext4 "${dev}p2" "$mnt"

	mkdir -pv "$mnt/boot"
	mount -v -t vfat "${dev}p1" "$mnt/boot"
}

disk_umount() # dev
{
	local dev="$1"

	umount -lv "${dev}p1"
	umount -lv "${dev}p2"
}

disk_partition() # dev
{
	local dev="$1"

	# TODO: Replace with sgdisk script

	gdisk "$dev" <<EOF
o
Y
n


+200M
ef00
n



8304
w
Y
EOF
}

# Shrink a disk's ext4 partition to minimal size.
disk_shrink() # device part_index [part_type]
{
	local device="$1"
	local part_index="$2"
	local part_type="${3:-8304}"

	local part="${device}p${part_index}"

	local disk_sector_size
	local part_block_count part_block_size
	local part_size part_size_padded
	local part_sector_count
	local part_uuid

	# Discard unused blocks.
	#fstrim

	# Resize partition to minimal size.
	e2fsck -f "$part"
	resize2fs "$part" 4G # -M

	disk_sector_size=$(<"/sys/block/${device##*/}/queue/hw_sector_size")

	part_block_count=$(dumpe2fs -h "$part" | grep -i '^Block count:' | cut -d':' -f2 | tr -d ' \t')
	part_block_size=$(dumpe2fs -h "$part" | grep -i '^Block size:' | cut -d':' -f2 | tr -d ' \t')

	part_size=$((part_block_count * part_block_size))
	part_size_padded=$((part_size + (part_size % disk_sector_size)))
	part_sector_count=$((part_size_padded / disk_sector_size))

	part_uuid=$(blkid "$part" -o value -s PARTUUID)

	gdisk "$device" <<EOF
p
d
$part_index
n
$part_index

+$part_sector_count
$part_type
x
c
$part_index
$part_uuid
p
w
Y
EOF
}
