# shellcheck shell=bash

# Mount default disk partitions.
disk_mount() # dev mnt
{
	local dev="$1"
	local mnt="$2"

	mkdir -pv "$mnt"
	mount -v -t ext4 "${dev}p3" "$mnt"

	mkdir -pv "$mnt/boot"
	mount -v -t vfat "${dev}p1" "$mnt/boot"
}

# Unmount default disk partitions.
disk_umount() # dev
{
	local dev="$1"

	umount -lv "${dev}p1"
	umount -lv "${dev}p3"
}

# Create default disk partitions.
disk_partition() # dev
{
	local dev="$1"

	# Clear partition tables.
	sgdisk -Z "$dev"

	# Number	Size	Type					Name
	# 1			200MiB	EFI System Partition	boot
	# 2			3.8GiB	Linux swap				swap
	# 3			?GiB	Linux x86-64 root (/)	root
	sgdisk "$dev" \
		--new "1:0:+${FS_ESP_SIZE}M" \
			--typecode 1:ef00 --change-name 1:boot \
		--new "2:0:+${FS_SWAP_SIZE}M" \
			--typecode 2:8200 --change-name 2:swap \
		--largest-new 3 \
			--typecode 3:8304 --change-name 3:root

	# Show result.
	sgdisk "$dev" -p
}

# Shrink a disk's last ext4 fs and partition to a given size in MiB.
disk_shrink() # device fs_size
{
	local device="$1"
	local fs_size="$2"
	local part

	local disk_sector_size
	local part_block_count part_block_size
	local part_size part_size_padded
	local part_sector_count
	local part_name part_uuid part_type

	# Get last partition information.
	part_index=$(partx --raw -o NR --noheading --nr -1 "$device")
	part_name=$(partx --raw -o NAME --noheading --nr -1 "$device")
	part_uuid=$(partx --raw -o UUID --noheading --nr -1 "$device")
	part_type=$(partx --raw -o TYPE --noheading --nr -1 "$device")
	part="${device}p${part_index}"

	# Resize partition to given size.
	e2fsck -f "$part"
	resize2fs "$part" "${fs_size}M"

	# Calculate new partition sector count.
	disk_sector_size=$(<"/sys/block/${device##*/}/queue/hw_sector_size")

	part_block_count=$(dumpe2fs -h "$part" | grep -i '^Block count:' | cut -d':' -f2 | tr -d ' \t')
	part_block_size=$(dumpe2fs -h "$part" | grep -i '^Block size:' | cut -d':' -f2 | tr -d ' \t')

	part_size=$((part_block_count * part_block_size))
	part_size_padded=$((part_size + (part_size % disk_sector_size)))
	part_sector_count=$((part_size_padded / disk_sector_size))

	sgdisk "$device" --print

	# Resize partition.
	sgdisk "$device" \
		--delete "$part_index" \
		--new "$part_index:0:+$part_sector_count" \
		--typecode "0:$part_type" \
		--change-name "0:$part_name" \
		--partition-guid "0:$part_uuid"

	sgdisk "$device" --print
}
