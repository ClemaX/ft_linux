#!/bin/bash

set -eEu

source ~/utils/logger.sh
source ~/utils/package.sh

glibc_version=$(ldd --version | head -n1 | rev | cut -d' ' -f1 | rev)

error_handler()
{
  error "$BASH_SOURCE:$LINENO: $BASH_COMMAND returned with unexpected exit status $?"
}

trap error_handler ERR

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

	pkg_extract "$LFS/sources/"m4*.tar*			pkg_build_m4
	pkg_extract "$LFS/sources/"ncurses*.tar*	pkg_build_ncurses
	pkg_extract "$LFS/sources/"bash*.tar*		pkg_build_bash
	pkg_extract "$LFS/sources/"coreutils*.tar*	pkg_build_coreutils
	pkg_extract "$LFS/sources/"diffutils*.tar*	pkg_build_diffutils
	pkg_extract "$LFS/sources/"file*.tar*		pkg_build_file
	pkg_extract "$LFS/sources/"findutils*.tar*	pkg_build_findutils
	pkg_extract "$LFS/sources/"gawk*.tar*		pkg_build_gawk
	pkg_extract "$LFS/sources/"grep*.tar*		pkg_build_grep
	pkg_extract "$LFS/sources/"gzip*.tar*		pkg_build_gzip
	pkg_extract "$LFS/sources/"make*.tar*		pkg_build_make
	pkg_extract "$LFS/sources/"patch*.tar*		pkg_build_patch
	pkg_extract "$LFS/sources/"sed*.tar*		pkg_build_sed
	pkg_extract "$LFS/sources/"tar*.tar*		pkg_build_tar
	pkg_extract "$LFS/sources/"xz*.tar*			pkg_build_xz

	pkg_build_binutils_pass2	binutils*/
	pkg_build_gcc_pass2			"$gcc_dir"
popd
