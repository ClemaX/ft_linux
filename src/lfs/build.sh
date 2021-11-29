#!/usr/bin/env bash

set -eEu

error_handler()
{
  error "$BASH_SOURCE:$LINENO: $BASH_COMMAND returned with unexpected exit status $?"
}

trap error_handler ERR

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
popd
