#!/usr/bin/env bash

set -eEu

ERROR_LOG=

error_handler()
{
	local lineno=$1
	local cmd=$2

	error "$BASH_SOURCE:$lineno: $cmd returned with unexpected exit status $?"
	
	[ -z "$ERROR_LOG" ] || cat "$ERROR_LOG"
}

trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

source /build/utils/logger.sh
source /build/utils/package.sh
source /build/utils/packages_software.sh

pushd /tmp
	# Install basic system software.
	for pkg in man-pages iana-etc glibc zlib bzip2 xz zstd file readline m4 bc \
		flex
	do
		pkg_extract /sources/$pkg*.tar* pkg_build_$pkg
	done

	pkg_extract /sources/tcl*-src*.tar* pkg_build_tcl

	for pkg in expect dejagnu binutils gmp mpfr mpc attr acl libcap shadow gcc \
		pkg-config ncurses sed psmisc gettext bison grep bash libtool gdbm \
		gperf expat inetutils less perl XML-Parser intltool autoconf automake \
		kmod elfutils libffi openssl Python ninja meson coreutils check \
		diffutils gawk findutils groff gzip iproute kbd libpipeline make \
		patch tar texinfo vim eudev man-db procps-ng util-linux e2fsprogs \
		sysklogd sysvinit
	do
		pkg_extract /sources/$pkg*.tar* pkg_build_$pkg
	done

	# TODO: Install UEFI grub

	# TODO: Optionally strip binaries

	rm -rf /tmp/*

	# Remove libtool archives.
	find /usr/lib /usr/libexec -name \*.la -delete

	# Remove the temporary compiler.
	find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf

	# Remove the temporary test user.
	userdel -r tester
popd
