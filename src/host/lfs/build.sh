#!/bin/bash

set -eEu

source ~/utils/logger.sh
source ~/utils/package.sh

glibc_version=$(ldd --version | head -n1 | rev | cut -d' ' -f1 | rev)

error_handler()
{
	local lineno=$1
	local cmd=$2

 	error "$BASH_SOURCE:$lineno: $cmd returned with unexpected exit status $?"
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# Prepare lfs file hierarchy.
lfs_prepare_fs() # dst
{
	dst="$1"

	info "Preparing lfs file hierarchy in $LFS..."
	# Create the bases folder structure
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
	pkg_extract "$LFS/sources/"binutils*.tar*	pkg_build_binutils

	# Build gcc.
	gcc_pkg="$(find "$LFS/sources" -maxdepth 1 -wholename "$LFS/sources/gcc-*.tar.*")"
	gcc_base="${gcc_pkg##*/}"
	gcc_dir="${gcc_base%.tar*}"

	debug "gcc: $gcc_pkg, gcc base: $gcc_base, gcc dir: $gcc_dir"

	mkdir -v "$gcc_dir"

	pkg_extract "$LFS/sources/"mpfr*.tar*		pkg_build_gcc_dep
	pkg_extract "$LFS/sources/"gmp*.tar*		pkg_build_gcc_dep
	pkg_extract "$LFS/sources/"mpc*.tar*		pkg_build_gcc_dep

	pkg_extract "$LFS/sources/"gcc*.tar*		pkg_build_gcc

	# Build Linux API Headers.
    pkg_extract "$LFS/sources/linux-stable.tar" pkg_build_kernel_headers

	# Build GLIBC.
	pkg_extract "$LFS/sources/"glibc*.tar*		pkg_build_glibc

	# Finalize the installation of the limits.h header.
	debug "Running mkheaders..."
	"$LFS/tools/libexec/gcc/$LFS_TGT/11.2.0/install-tools/mkheaders"

	# Build libstdc++ from gcc.
	pkg_build_libstdc++ "$gcc_dir"

	# Build additional tools.
	for pkg in m4 ncurses bash coreutils diffutils file findutils gawk grep gzip make patch sed tar xz
	do
		pkg_extract "$LFS/sources/$pkg"*.tar*	pkg_build_$pkg
	done

	pkg_build_binutils_pass2	binutils*/
	pkg_build_gcc_pass2			"$gcc_dir"
popd
