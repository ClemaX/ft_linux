#!/bin/bash

set -eEu

SCRIPTDIR=~

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/package.sh"

error_handler()
{
	local src=$1
	local lineno=$2
	local cmd=$3

 	error "$src:$lineno: $cmd returned with unexpected exit status $?"
}

trap 'error_handler "${BASH_SOURCE[0]}" "$LINENO" "$BASH_COMMAND"' ERR

# Prepare lfs file hierarchy.
lfs_prepare_fs() # dst
{
	dst="$1"

	info "Preparing lfs file hierarchy in $LFS..."
	# Create the bases folder structure.
	mkdir -pv "$dst"/{etc,var} "$dst"/usr/{bin,lib,sbin}

	# Link the bin lib and sbin directories to their /usr/... counterparts.
	pushd "$dst"
		for dir in bin lib sbin
		do
			ln -sv "usr/$dir" "$dir"
		done
	popd

	# Create architecture specific directories.
	case $(uname -m) in
		x86_64) mkdir -pv "$dst/lib64";;
	esac

	mkdir -pv "$dst/tools"
}

lfs_prepare_fs "$LFS"

pushd "/tmp"
	ls "$LFS/sources/"*.tar* > packages.lst

	# Build binutils.
	pkg_extract "$LFS/sources/"binutils*.tar*		pkg_build_binutils

	# Build gcc.
	gcc_pkg=$(echo "$LFS/sources/"gcc*.tar*)
	gcc_base="${gcc_pkg##*/}"
	export GCC_DIR="${gcc_base%.tar*}"

	mkdir -v "$GCC_DIR"

	pkg_extract "$LFS/sources/"mpfr*.tar*			pkg_build_gcc_dep
	pkg_extract "$LFS/sources/"gmp*.tar*			pkg_build_gcc_dep
	pkg_extract "$LFS/sources/"mpc*.tar*			pkg_build_gcc_dep

	pkg_extract "$LFS/sources/"gcc*.tar*			pkg_build_gcc

	# Build Linux API Headers.
	pkg_extract "$LFS/sources/"linux-stable*.tar*	pkg_build_kernel_headers

	# Build GLIBC.
	pkg_extract "$LFS/sources/"glibc*.tar*			pkg_build_glibc

	# Finalize the installation of the limits.h header.
	debug "Running mkheaders..."
	"$(find "$LFS/tools/libexec/gcc/$LFS_TGT/" -maxdepth 2 -path '*.*.*/install-tools' -print -quit)/mkheaders"

	# Build libstdc++ from gcc.
	pkg_build_libstdc++ "$GCC_DIR"

	# Build temporary tools.
	for pkg in m4 ncurses bash coreutils diffutils file findutils gawk grep \
		gzip make patch sed tar xz
	do
		pkg_extract "$LFS/sources/"$pkg*.tar*		pkg_build_$pkg
	done

	pkg_build_binutils_pass2	binutils*/
	pkg_build_gcc_pass2			"$GCC_DIR"
popd
