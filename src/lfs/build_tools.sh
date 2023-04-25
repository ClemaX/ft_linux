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

PACKAGES=(gettext bison perl python texinfo util-linux)

# Initialize log files.
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# Build additional temporary tools.
pushd "$SCRIPTDIR/packages/temporary-tools"
	for pkg in "${PACKAGES[@]}"
	do
		"$SCRIPTDIR/utils/pkg.sh" build "$pkg"
		"$SCRIPTDIR/utils/pkg.sh" install "$pkg"
	done
popd

info "Cleaning up..."

# Remove installed documentations to save space.
rm -vrf /usr/share/{info,man,doc}/*

# Remove libtool .la files that are harmful when using dynamic linking.
find /usr/{lib,libexec} -name '*.la' -delete

# Remove cross-compilation tools.
rm -vrf /tools

# Remove temporary tools build cache.
pushd /cache/pkg/
	for pkg in "${PACKAGES[@]}"
	do
		rm -vrf "./${pkg:?}/"
	done
popd
