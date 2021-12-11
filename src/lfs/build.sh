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

log_init()
{
	touch /var/log/{btmp,lastlog,faillog,wtmp}
	chgrp -v utmp /var/log/lastlog
	chmod -v 664  /var/log/lastlog
	chmod -v 600  /var/log/btmp
}

log_init

pushd /tmp
	pkg_extract /sources/gcc*.tar* pkg_build_libstdc++
	pkg_extract /sources/gettext*.tar* pkg_build_gettext
	pkg_extract /sources/bison*.tar* pkg_build_bison
	pkg_extract /sources/perl*.tar* pkg_build_perl
	pkg_extract /sources/Python*.tar* pkg_build_python
popd
