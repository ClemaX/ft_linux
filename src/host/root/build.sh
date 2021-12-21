#!/bin/bash

set -eEu

source ~/utils/logger.sh
source ~/utils/disk.sh
source ~/utils/cache.sh
source ~/utils/image.sh
source ~/utils/linux.sh
source ~/utils/sources.sh
source ~/utils/lfs_chroot.sh
source ~/utils/lfs_backup.sh

lfs_base_url="https://www.linuxfromscratch.org/lfs/view/$LFS_VERSION"

lfs_backup_file="/cache/lfs-temp-tools-$LFS_VERSION.tar.xz"

error_handler()
{
	local lineno=$1
	local cmd=$2

 	error "$BASH_SOURCE:$lineno: $cmd returned with unexpected exit status $?"
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# Create a new disk image.
img_new "$IMG_DST" "$IMG_SIZE"

loop_setup "$LOOP_DEV" "$IMG_DST"

disk_partition "$LOOP_DEV"

loop_partitions "$LOOP_DEV"

mkfs.ext4 -L EFI "${LOOP_DEV}p1"
mkfs.ext4 -L root "${LOOP_DEV}p2"

disk_mount "$LOOP_DEV" "$LFS"

if [ -f "$lfs_backup_file" ]
then
	lfs_restore "$LFS" "$lfs_backup_file"
else
	# Make files readable by anyone
	umask 022

	# Fetch sources.
	sources_fetch "$lfs_base_url" "$LFS/sources"
	chown -v lfs "$LFS" "$LFS/sources"

	# Build LFS filesystems.
	pushd /home/lfs
		env -i LFS="$LFS" BASH_ENV='~/.bashrc' su lfs -c "~/build.sh"
	popd

	# Reset root permissions.
	lfs_chown root:root "$LFS"
	chown -R root:root /tmp

	# Add builder scripts to the filesystem.
	cp -r chroot "$LFS/build"

	# Initialize the filesystem.
	lfs_chroot "$LFS" /bin/bash --login +h /build/init.sh
	# Build additional temporary tools.
	lfs_chroot "$LFS" /bin/bash --login +h /build/build_tools.sh

	# Backup the temporary filesystem.
	lfs_backup "$LFS" "$lfs_backup_file"
fi

disk_umount "$LOOP_DEV"
