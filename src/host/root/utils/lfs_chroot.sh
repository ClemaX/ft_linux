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
