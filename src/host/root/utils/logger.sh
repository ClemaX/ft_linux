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
	echo "$DEBUG$@$ENDL" 1>&2
}

info()
{
	echo "$INFO$@$ENDL" 1>&2
}

warning()
{
	echo "$WARNING$@$ENDL" 1>&2
}

error()
{
	echo "$ERROR$@$ENDL" 1>&2
}

pushd()
{
	echo -n "$DEBUG" 1>&2
	builtin pushd $@ 1>&2
	echo -n "$ENDL" 1>&2
}

popd()
{
	echo -n "$DEBUG" 1>&2
	builtin popd $@ 1>&2
	echo -n "$ENDL" 1>&2
}
