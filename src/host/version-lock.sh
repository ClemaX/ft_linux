#!/bin/bash

set -euo pipefail

while read -r package < packages.lst
do
	version=$(dpkg -s ${package%=*} | grep Version | cut -d' ' -f2)
	echo "$package=$version"
done
