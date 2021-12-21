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

# Initialize log files.
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# Build tools.
pushd /tmp
	pkg_extract /sources/gcc*.tar*			pkg_build_libstdc++
	pkg_extract /sources/Python*.tar*		pkg_build_python

	for pkg in gettext bison perl texinfo util-linux
	do
		pkg_extract /sources/$pkg*.tar*		pkg_build_$pkg
	done
popd

info "Cleaning up..."

# Remove installed documentations to save space.
rm -rf /usr/share/{info,man,doc}/*

# Remove libtool .la files that are harmful when using dynamic linking.
find /usr/{lib,libexec} -name \*.la -delete

# Remove cross-compilation tools.
rm -rf /tools
