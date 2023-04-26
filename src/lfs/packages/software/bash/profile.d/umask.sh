# shellcheck shell=bash

# By default, the umask should be set.
if [ "$(id -gn)" = "$(id -un)" ] && [ $EUID -gt 99 ]
then
  umask 002
else
  umask 022
fi
