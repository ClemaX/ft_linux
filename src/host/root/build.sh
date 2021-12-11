#!/bin/bash

set -eEu

source ~/utils/logger.sh
source ~/utils/disk.sh
source ~/utils/cache.sh
source ~/utils/image.sh
source ~/utils/linux.sh
source ~/utils/sources.sh

lfs_base_url="https://www.linuxfromscratch.org/lfs/view/$LFS_VERSION"

lfs_backup="/cache/lfs-temp-tools-$LFS_VERSION.tar.xz"

error_handler()
{
	local lineno=$1
	local cmd=$2

 	error "$BASH_SOURCE:$lineno: $cmd returned with unexpected exit status $?"
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

lfs_chown() # owner root
{
	owner="${1:-root:root}"
	root="${2:-$LFS}"

	info "Setting ownership to $owner on $LFS..."

	# TODO: Remove sources
	pushd "$root"
		chown "$owner" "."
		chown -R "$owner" {usr,lib,var,etc,bin,sbin,tools,sources}
		case $(uname -m) in
			x86_64) chown -R "$owner" lib64;;
		esac
	popd
}

lfs_chroot_teardown() # root
{
	root="${1:-$LFS}"

	pushd "$root"
		info "Tearing down kernel file systems in $root..."

		umount "$root/dev/pts" || warning "Failed to unmount a filesystem!"
		umount "$root/"{sys,proc,run} || warning "Failed to unmount a filesystem!"

		umount "$root/dev" || warning "Failed to unmount $root/dev!"

		umount "$root/cache" || warning "Failed to unmount $root/cache!"
		umount "$root/tmp" || warning "Failed to unmount $root/tmp!"

		rm -vf "$root/dev/"{console,null}

		rmdir -v "$root/cache"
	popd
}

lfs_chroot() # root [cmd]
{
	LFS_PS1='(lfs chroot) \u:\w\$ '

	root="${1:-$LFS}"; shift

	pushd "$root"
		info "Mounting kernel file systems to $root..."

		# Create mountpoints.
		mkdir -pv {dev,proc,sys,run,cache,tmp}

		# Teardown on unexpected exit.
		trap "lfs_chroot_teardown '$root'" EXIT

		# Create console devices.
		mknod -m 600 dev/console	c 5 1
		mknod -m 666 dev/null		c 1 3

		# Mount /dev.
		mount -v --bind /dev		dev
		mount -v --bind	/dev/pts	dev/pts
		mount -vt proc	proc		proc
		mount -vt sysfs	sysfs		sys
		mount -vt tmpfs	tmpfs		run

		if [ -h dev/shm ]; then
			mkdir -pv "$(readlink dev/shm)"
		fi

		# Mount /cache.
		mount -v --bind	/cache		cache

		# Mount /tmp.
		mount -v --bind /tmp		tmp

		info "Changing root to $root..."
		# Change root directory.
		chroot . /usr/bin/env -i \
			HOME=/root \
			TERM="$TERM" \
			PS1="$LFS_PS1" \
			PATH=/usr/bin:/usr/sbin \
			${@:-/bin/bash --login +h}

		# Teardown.
		trap - EXIT
		lfs_chroot_teardown "$root"
	popd
}

lfs_backup() # root dest
{
	local root="${1:-$LFS}"
	local dest="${2:-lfs-temp-tools-$LFS_VERSION.tar.xz}"

	info "Backing up $root to $dest..."
	tar -cJpf "$dest" "$root"
}

lfs_restore() # root src
{
	local root="${1:-$LFS}"
	local src="${2:-lfs-temp-tools-$LFS_VERSION.tar.xz}"

	info "Restoring $root from $src"
	pushd "$root"
		rm -rf ./*
		tar -xpf "$src"
	popd
}


# Create a new disk image.
img_new "$IMG_DST" "$IMG_SIZE"

loop_setup "$LOOP_DEV" "$IMG_DST"

disk_partition "$LOOP_DEV"

loop_partitions "$LOOP_DEV"

mkfs.ext4 -L EFI "${LOOP_DEV}p1"
mkfs.ext4 -L root "${LOOP_DEV}p2"

disk_mount "$LOOP_DEV" "$LFS"

if [ -f "$lfs_backup" ]
then
	lfs_restore "$LFS" "$lfs_backup"
else
	# Make files readable by anyone
	umask 022
	sources_fetch "$lfs_base_url" "$LFS/sources"
	chown -v lfs "$LFS" "$LFS/sources"

	# Build LFS filesystems.
	pushd /home/lfs
		env -i LFS="$LFS" BASH_ENV='~/.bashrc' su lfs -c "~/build.sh"
	popd

	# Reset root permissions.
	lfs_chown root:root "$LFS"

	# Add builder scripts to the filesystem.
	cp -r chroot "$LFS/build"

	# Chroot into the filesystem.
	lfs_chroot "$LFS" /bin/bash --login +h /build/init.sh
	lfs_chroot "$LFS" /bin/bash --login +h /build/build.sh

	# Backup the current lfs root.
	lfs_backup "$LFS" "$lfs_backup"
fi
