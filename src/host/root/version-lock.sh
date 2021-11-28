#!/bin/bash

set -euo pipefail

while IFS= read -r package
do
	if ! [ -z "$package" ]
	then
		version=$(dpkg -s ${package%=*} | grep Version | cut -d' ' -f2)
		echo "$package=$version"
	fi
done < packages.lst
