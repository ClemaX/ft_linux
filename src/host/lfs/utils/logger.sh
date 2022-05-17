# shellcheck shell=bash

set -e

if [[ "$TERM" == *xterm* ]] || [[ "$TERM" == alacritty ]]
then
	COLOR_DEBUG=$'\033[1;34m'
	COLOR_INFO=$'\033[1;32m'
	COLOR_WARNING=$'\033[1;33m'
	COLOR_ERROR=$'\033[1;31m'
	COLOR_DEFAULT=$'\033[0m'
fi

DEBUG="${COLOR_DEBUG:-}"
INFO="${COLOR_INFO:-}"
WARNING="${COLOR_WARNING:-}"
ERROR="${COLOR_ERROR:-}"
ENDL="${COLOR_DEFAULT:-}"

debug()
{
	local caller="${CALLER:-${FUNCNAME[1]}}"
	echo "$DEBUG$caller: $*$ENDL" 1>&2
}

info()
{
	local caller="${CALLER:-${FUNCNAME[1]}}"
	echo "$INFO$caller: $*$ENDL" 1>&2
}

warning()
{
	local caller="${CALLER:-${FUNCNAME[1]}}"
	echo "$WARNING$caller: $*$ENDL" 1>&2
}

error()
{
	local caller="${CALLER:-${FUNCNAME[1]}}"
	echo "$ERROR$caller: $*$ENDL" 1>&2
}

pushd()
{
	echo -n "$DEBUG${FUNCNAME[0]}: " 1>&2
	builtin pushd "$@" 1>&2
	echo -n "$ENDL" 1>&2
}

# shellcheck disable=SC2120
popd()
{
	echo -n "$DEBUG${FUNCNAME[0]}: " 1>&2
	builtin popd "$@" 1>&2
	echo -n "$ENDL" 1>&2
}

# TODO: Add mkdir verbose wrapper (also mv cp etc...)
