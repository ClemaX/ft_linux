#!/bin/bash

set -eEu

SCRIPTDIR=~

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/disk.sh"
source "$SCRIPTDIR/utils/cache.sh"
source "$SCRIPTDIR/utils/image.sh"
source "$SCRIPTDIR/utils/git.sh"
source "$SCRIPTDIR/utils/sources.sh"
source "$SCRIPTDIR/utils/lfs_chroot.sh"
source "$SCRIPTDIR/utils/lfs_backup.sh"
source "$SCRIPTDIR/utils/progress_bar.sh"

export PROGRESS_BAR_ACCENT=4
export PROGRESS_BAR_PREFIX_FW=-27

lfs_base_url="https://www.linuxfromscratch.org/lfs/view/$LFS_VERSION"

lfs_backup_file="/cache/lfs-temp-tools-$LFS_VERSION.tar.xz"

error_handler()
{
	local src="$1"
	local lineno="$2"
	local cmd="$3"

	error "$src:$lineno: $cmd returned with unexpected exit status $?"
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
	progress_init 7
else
	progress_init 11
fi

# Create a new disk image.
progress "Creating disk image"
img_new "$IMG_DST" "$IMG_SIZE"

loop_setup "$IMG_DST"

progress "Partitioning disk"
disk_partition "$LOOP_DEV"

loop_partitions

progress "Initializing partitions"
mkfs.fat -F32 -n EFI "${LOOP_DEV}p1"
mkfs.ext4 -L root "${LOOP_DEV}p2"

progress "Mounting disk"
disk_mount "$LOOP_DEV" "$LFS"

if [ -f "$lfs_backup_file" ]
then
	progress "Restoring backup"
	lfs_restore "$LFS" "$lfs_backup_file"

	# TODO: Fix permission in backup and remove this
	chmod 755 "$LFS"

	# TODO: Remove when stable
		chown -v lfs "$LFS/sources" "$LFS"

		info "Fetching sources"
		# Make files readable by anyone
		umask 022

		# Fetch sources.
		sources_fetch "$lfs_base_url" "$LFS/sources" /cache lfs

		chown -v root "$LFS" "$LFS/sources"
	#
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
		# shellcheck disable=SC2088
		env -i \
			LFS="$LFS" \
			LFS_VERSION="$LFS_VERSION" \
			LFS_LOCALVERSION="$LFS_LOCALVERSION" \
			LFS_HOSTNAME="$LFS_HOSTNAME" \
			XZ_DEFAULTS="$XZ_DEFAULTS" \
			BASH_ENV='~/.bashrc' \
			su lfs -c '~/build_toolchain.sh'
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

progress "Shrinking image"

disk_umount "$LOOP_DEV"

disk_shrink "$LOOP_DEV" 2
img_shrink "$IMG_DST"
