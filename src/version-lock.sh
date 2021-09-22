#!/bin/bash

set -euo pipefail

packages=$(<packages.txt)

for package in $packages
do
	version=$(dpkg -s ${package%=*} | grep Version | cut -d' ' -f2)
	echo "$package=$version"
done
