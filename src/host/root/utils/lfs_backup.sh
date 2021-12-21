lfs_backup() # root dest
{
	local root="${1:-$LFS}"
	local dest="${2:-lfs-temp-tools-$LFS_VERSION.tar.xz}"

	info "Backing up $root to $dest..."
	pushd "$root"
		tar -cJpf "$dest" .
	popd
}

lfs_restore() # root src
{
	local root="${1:-$LFS}"
	local src="${2:-lfs-temp-tools-$LFS_VERSION.tar.xz}"

	local boot=""

	info "Restoring $root from $src..."
	pushd "$root"
		if mountpoint boot
		then
			boot=$(findmnt -n -o SOURCE boot)
			debug "Unmounting boot partition..."
			umount -v boot
		fi

		debug "Cleaning file-system..."
		rm -rf *

		if [ -n "$boot" ]
		then
			debug "Remounting boot partition..."
			mkdir -vp boot
			mount -v "$boot" boot
		fi

		debug "Restoring backup..."
		tar --no-same-owner -xpf "$src"
	popd
}
