#!/usr/bin/env bash

set -eEu

error_handler()
{
	local lineno=$1
	local cmd=$2

 	error "$BASH_SOURCE:$lineno: $cmd returned with unexpected exit status $?"
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

source /build/utils/logger.sh
source /build/utils/package.sh

pushd /tmp
	# Install basic system software.
	for pkg in man-pages iana-etc glibc zlib bzip2 xz zstd file readline m4 bc \
		flex
	do
		pkg_extract /sources/$pkg*.tar* pkg_build_$pkg
	done

	pkg_extract /sources/tcl*-src*.tar* pkg_build_tcl

	for pkg in expect dejagnu binutils gmp mpfr attr acl libcap shadow gcc \

#		pkg-config ncurses sed psmisc gettext bison grep bash libtool gdbm \
#		gperf expat inetutils less perl XML-Parser intltool autoconf automake \
#		kmod elfutils libffi openssl Python ninja meson coreutils check \
#		diffutils gawk findutils groff grub gzip iproute kbd libpipeline make \
#		patch tar texinfo vim eudev man-db procps-ng util-linux e2fsprogs \
#		sysklogd sysvinit
	do
		pkg_extract /sources/$pkg*.tar* pkg_build_$pkg
	done
popd
