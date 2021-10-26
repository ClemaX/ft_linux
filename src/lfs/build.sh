#!/bin/bash

set -eEu

source ~/utils/package.sh

glibc_version=$(ldd --version | head -n1 | cut -d" " -f2-)

error_handler()
{
  echo "$BASH_SOURCE:$LINENO: $BASH_COMMAND returned with unexpected exit status $?"
}

trap error_handler ERR

# Prepare lfs file hierarchy.
lfs_prepare_fs() # dst
{
	dst="$1"

	echo "Preparing lfs file hierarchy in $LFS..."
	# Create the bases folder structure
	mkdir -pv "$dst"/{etc,var} "$dst"/usr/{bin,lib,sbin}

	# Link the bin lib and sbin directories to their /usr/... counterparts.
	for i in bin lib sbin
	do
		ln -sv "$LFS/usr/$i" "$dst/$i"
	done

	# Create architecture specific directories.
	case $(uname -m) in
		x86_64) mkdir -pv "$dst/lib64";;
	esac

	mkdir -pv "$dst/tools"
}

lfs_prepare_fs "$LFS"

pushd "/tmp"
	ls -l "$LFS/sources/"*.tar* > packages.lst

	# Build binutils
	pkg_extract "$LFS/sources/"binutils*.tar* pkg_build_binutils

	# Build gcc
	gcc_pkg="$LFS/sources/"gcc*.tar.*
	gcc_dir="${gcc%%.tar*}"

	mkdir -v "$gcc"

	pkg_extract "$LFS/sources/"mpfr*.tar* pkg_build_gcc_dep
	pkg_extract "$LFS/sources/"gmp*.tar* pkg_build_gcc_dep
	pkg_extract "$LFS/sources/"mpc*.tar* pkg_build_gcc_dep

	pkg_extract "$LFS/sources/"gcc*.tar* pkg_build_gcc

	# Build Linux API Headers
    # We are using git instead
    # pkg_extract linux*.tar* pkg_build_kernel
	# TODO: Rename to build_kernel_headers
	pkg_build_kernel "$LFS/sources/linux-stable"

	# TODO: Extract the remaining package and build them
	while read -r pkg < packages.lst
	do
		echo TODO: pkg_extract "$pkg"
	done
popd
