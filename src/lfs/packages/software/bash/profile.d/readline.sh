# shellcheck shell=bash

# Set up the INPUTRC environment variable.
if [ -z "$INPUTRC" ] && ! [ -f "$HOME/.inputrc" ]
then
	INPUTRC=/etc/inputrc
fi

export INPUTRC
