#!/usr/bin/env bash

set -eEu

ERROR_LOG=

error_handler()
{
	local src=$1
	local lineno=$2
	local cmd=$3

	error "$src:$lineno: $cmd returned with unexpected exit status $?"

	[ -z "$ERROR_LOG" ] || tail "$ERROR_LOG"
}

trap 'error_handler "${BASH_SOURCE[0]}" "$LINENO" "$BASH_COMMAND"' ERR

SCRIPTDIR=/build

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/package.sh"
source "$SCRIPTDIR/utils/packages_software.sh"

# Install basic system software.
pushd "$SCRIPTDIR/packages/software"
	for pkg in man-pages iana-etc glibc zlib bzip2 xz zstd file readline m4 bc \
		flex tcl
	do
		"$SCRIPTDIR/utils/pkg.sh" build "$pkg"
		"$SCRIPTDIR/utils/pkg.sh" install "$pkg"
	done
popd

pushd /tmp
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

	if [ "$STRIP_BINARIES" = true ]
	then
		save_usrlib="$(cd /usr/lib; ls ld-linux*)
			libc.so.6
			libthread_db.so.1
			libquadmath.so.0.0.0
			libstdc++.so.6.0.29
			libitm.so.1.0.0
			libatomic.so.1.2.0"

		pushd /usr/lib

		for LIB in $save_usrlib
		do
			objcopy --only-keep-debug "$LIB" "$LIB.dbg"
			cp "$LIB" "/tmp/$LIB"
			strip --strip-unneeded "/tmp/$LIB"
			objcopy --add-gnu-debuglink="$LIB.dbg" "/tmp/$LIB"
			install -vm755 "/tmp/$LIB" /usr/lib
			rm "/tmp/$LIB"
		done

		online_usrbin="bash find strip"
		online_usrlib="libbfd-2.38.so
			libhistory.so.8.1
			libncursesw.so.6.3
			libm.so.6
			libreadline.so.8.1
			libz.so.1.2.11
			$(cd /usr/lib; find libnss*.so* -type f)"

		for BIN in $online_usrbin
		do
			cp "/usr/bin/$BIN" "/tmp/$BIN"
			strip --strip-unneeded "/tmp/$BIN"
			install -vm755 "/tmp/$BIN" /usr/bin
			rm "/tmp/$BIN"
		done

		for LIB in $online_usrlib
		do
			cp "/usr/lib/$LIB" "/tmp/$LIB"
			strip --strip-unneeded "/tmp/$LIB"
			install -vm755 "/tmp/$LIB" /usr/lib
			rm "/tmp/$LIB"
		done

		for i in $(find /usr/lib -type f -name '*.so*' ! -name '*dbg') \
				$(find /usr/lib -type f -name '*.a') \
				$(find /usr/{bin,sbin,libexec} -type f)
		do
			case "$online_usrbin $online_usrlib $save_usrlib" in
				*$(basename "$i")* ) ;;
				* ) strip --strip-unneeded "$i" || : ;;
			esac
		done

		unset BIN LIB save_usrlib online_usrbin online_usrlib
	fi

	rm -rf /tmp/*

	# Remove libtool archives.
	find /usr/lib /usr/libexec -name '*.la' -delete

	# Remove the temporary compiler.
	find /usr -depth -name "$(uname -m)-lfs-linux-gnu*" -exec rm -rf {} \;

	# Remove the temporary test user.
	userdel -r tester
popd
