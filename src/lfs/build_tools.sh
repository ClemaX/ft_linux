#!/usr/bin/env bash

set -eEu

error_handler()
{
	local src=$1
	local lineno=$2
	local cmd=$3

 	error "$src:$lineno: $cmd returned with unexpected exit status $?"
}

trap 'error_handler "${BASH_SOURCE[0]}" "$LINENO" "$BASH_COMMAND"' ERR

SCRIPTDIR=/build

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/package.sh"
source "$SCRIPTDIR/utils/packages_tools.sh"

# Initialize log files.
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# Build tools.
pushd /tmp
	pkg_extract /sources/gcc*.tar*			pkg_build_libstdc++

	for pkg in gettext bison perl Python texinfo util-linux
	do
		pkg_extract /sources/$pkg*.tar*		pkg_build_$pkg
	done
popd

info "Cleaning up..."

# Remove installed documentations to save space.
rm -rfv /usr/share/{info,man,doc}/*

# Remove libtool .la files that are harmful when using dynamic linking.
find /usr/{lib,libexec} -name '*.la' -delete

# Remove cross-compilation tools.
rm -rf /tools
