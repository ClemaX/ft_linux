# shellcheck shell=bash

set -e

lfs_backup() # root dest
{
	local root="${1:-$LFS}"
	local dest="${2:-/cache/lfs-temp-tools-$LFS_VERSION.tar.xz}"

	local backup_dir
	local backup_file

	backup_dir=$(dirname "$dest")
	backup_file=$(basename "$dest")

	info "Backing up $root to $dest..."
	pushd "$root"
		tar -cJpf "$dest" .
	popd

	pushd "$backup_dir"
		md5sum "$backup_file" > "$backup_file.md5"
	popd
}

lfs_restore() # root src
{
	local root="${1:-$LFS}"
	local src="${2:-/cache/lfs-temp-tools-$LFS_VERSION.tar.xz}"

	local backup_dir
	local backup_file
	local boot=""

	backup_dir=$(dirname "$src")
	backup_file=$(basename "$src")

	info "Restoring $root from $src..."

	pushd "$backup_dir"
		if ! md5sum --quiet --check "$backup_file.md5"
		then
			error "$src: md5sum does not match!" && false
		fi
	popd

	pushd "$root"
		if mountpoint boot
		then
			boot=$(findmnt -n -o SOURCE boot)
			debug "Unmounting boot partition..."
			umount -v boot
		fi

		debug "Cleaning file-system..."
		rm -rf ./*

		if [ -n "$boot" ]
		then
			debug "Remounting boot partition..."
			mkdir -vp boot
			mount -v "$boot" boot
		fi

		debug "Restoring backup..."
		tar -xpf "$src"
	popd
}
