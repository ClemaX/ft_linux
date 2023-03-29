# shellcheck shell=bash

set -e

lfs_chown() # owner root
{
	owner="${1:-root:root}"
	root="${2:-$LFS}"

	info "Setting ownership to $owner on $root..."

	# TODO: Remove sources
	pushd "$root"
		chown "$owner" "."
		chown -R "$owner" {usr,lib,var,etc,bin,sbin,tools,sources}
		case $(uname -m) in
			x86_64) chown -R "$owner" lib64;;
		esac
	popd
}

lfs_chroot_umount() # root [mountpoint]...
{
	local root="$1"; shift

	for mountpoint in "$@"
	do
		umount -lv "$root/$mountpoint" || warning "Failed to unmount $root/$mountpoint!"
	done
}

lfs_chroot_teardown() # root
{
	local root="${1:-$LFS}"

	pushd "$root"
		if mountpoint dev/
		then
			info "Tearing down kernel filesystems in $root..."

			# Unlink package cache.
			rm -vf var/cache/pkg

			# Unmount kernel filesystems and bind mounts.
			lfs_chroot_umount "$root" dev/pts {sys,proc,run} dev cache tmp

			# Remove console devices.
			rm -vf dev/{console,null}

			# Remove temporary cache mountpoint.
			[ -d cache ] && rmdir -v cache
		fi
	popd
}

lfs_chroot() # root [cmd]
{
	local LFS_PS1=${LFS_PS1:-'(lfs chroot) \u:\w\$ '}

	local root="${1:-$LFS}"; shift

	pushd "$root"
		info "Mounting kernel filesystems to $root..."

		# Create mountpoints.
		mkdir -pv {dev,proc,sys,run,cache,tmp}

		# Create console devices.
		[ -e dev/console	] || mknod -m 600 dev/console	c 5 1
		[ -e dev/null		] || mknod -m 666 dev/null		c 1 3

		# Mount /dev.
		mount -v	--bind	/dev		dev
		mount -v	--bind	/dev/pts	dev/pts
		mount -vt	proc	proc		proc
		mount -vt	sysfs	sysfs		sys
		mount -vt	tmpfs	tmpfs		run

		if [ -h dev/shm ]; then
			mkdir -pv "$(readlink dev/shm)"
		fi

		# Mount /cache.
		mount -v --bind	/cache		cache

		# Mount /tmp.
		mount -v --bind /tmp		tmp

		# Link package cache.
		mkdir -vp cache/pkg
		ln -vs /cache/pkg var/cache

		[ $# -eq 0 ] && set -- /bin/bash --login +h

		info "Changing root to $root..."
		# Change root directory.
		chroot . /usr/bin/env -i \
			HOME=/root \
			TERM="$TERM" \
			PS1="$LFS_PS1" \
			PATH=/usr/bin:/usr/sbin \
			HOST_OPTIMIZE="$HOST_OPTIMIZE" \
			SKIP_TESTS="$SKIP_TESTS" \
			STRIP_BINARIES="$STRIP_BINARIES" \
			PAGE="$PAGE" \
			"$@"

		lfs_chroot_teardown "$root"
	popd
}
