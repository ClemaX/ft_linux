# shellcheck shell=bash
# Begin ~/.profile
# Personal environment variables and startup programs.

if [ -d "$HOME/bin" ]; then
    pathprepend "$HOME/bin"
fi

# Set up user specific i18n variables.
# Default is 'en_US.UTF-8'.
#export LANG='<ll>_<CC>.<charmap><@modifiers>'

# End ~/.profile
