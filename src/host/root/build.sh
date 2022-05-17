#!/bin/bash

set -eEu

source ~/utils/logger.sh
source ~/utils/disk.sh
source ~/utils/cache.sh
source ~/utils/image.sh
source ~/utils/git.sh
source ~/utils/sources.sh
source ~/utils/lfs_chroot.sh
source ~/utils/lfs_backup.sh
source ~/utils/progress_bar.sh

PROGRESS_BAR_PREFIX_FW=-27

lfs_base_url="https://www.linuxfromscratch.org/lfs/view/$LFS_VERSION"

lfs_backup_file="/cache/lfs-temp-tools-$LFS_VERSION.tar.xz"

error_handler()
{
	local src="$1"
	local lineno="$2"
	local cmd="$3"

 	error "$BASH_SOURCE:$lineno: $cmd returned with unexpected exit status $?"
}

exit_handler()
{
	info "Cleaning up..."
	if mountpoint "$LFS"
	then
		lfs_chroot_teardown "$LFS"
		disk_umount "$LOOP_DEV"
	fi
	loop_teardown
	progress_destroy
}

trap 'error_handler "$BASH_SOURCE" "$LINENO" "$BASH_COMMAND"' ERR
trap 'exit_handler' EXIT

# Initialize progress bar
if [ -f "$lfs_backup_file" ]
then
	progress_init 6
else
	progress_init 10
fi

# Create a new disk image.
progress "Creating disk image"
img_new "$IMG_DST" "$IMG_SIZE"

loop_setup "$IMG_DST"

progress "Partitioning disk"
disk_partition "$LOOP_DEV"

loop_partitions

progress "Initializing partitions"
mkfs.ext4 -L EFI "${LOOP_DEV}p1"
mkfs.ext4 -L root "${LOOP_DEV}p2"

progress "Mounting disk"
disk_mount "$LOOP_DEV" "$LFS"

if [ -f "$lfs_backup_file" ]
then
	progress "Restoring backup"
	lfs_restore "$LFS" "$lfs_backup_file"
else
	progress "Fetching sources"
	# Make files readable by anyone
	umask 022

	# Fetch sources.
	sources_fetch "$lfs_base_url" "$LFS/sources" /cache lfs
	chown -v lfs "$LFS" "$LFS/sources"

	progress "Building toolchain"
	# Build LFS toolchain.
	pushd /home/lfs
		env -i LFS="$LFS" BASH_ENV='~/.bashrc' su lfs -c "~/build_toolchain.sh"
	popd

	# Reset root permissions.
	lfs_chown root:root "$LFS"
	chown -R root:root /tmp

	progress "Initializing filesystem"
	# Add builder scripts to the filesystem.
	cp -r chroot "$LFS/build"

	# Initialize the filesystem.
	lfs_chroot "$LFS" /bin/bash --login +h /build/init.sh

	# Build additional temporary tools.
	progress "Building temporary tools"
	lfs_chroot "$LFS" /bin/bash --login +h /build/build_tools.sh

	# Backup the temporary filesystem.
	progress "Backing up"
	lfs_backup "$LFS" "$lfs_backup_file"
fi

# TODO: Remove when stable
# Update builder scripts in the filesystem.
cp -r chroot/* "$LFS/build"

progress "Building system software"

lfs_chroot "$LFS" /bin/bash --login +h /build/build_software.sh

# TODO: Uncomment when stable
#disk_umount "$LOOP_DEV"
