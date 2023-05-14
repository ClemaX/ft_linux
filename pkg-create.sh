#!/bin/bash

set -euo pipefail

# Get user input.
read -rp "Enter source URL: " src_url
read -rp "Enter source extension: " src_ext
read -rp "Enter MD5SUM: " md5sum
read -rp "Enter package name: " pkg_name
read -rp "Enter package version: " pkg_version
read -rp "Enter repo name: " repo

# Append URL to sources file.
echo "$src_url" >> "src/host/root/sources/$repo.lst"

# Append MD5SUM to md5 file.
echo "$md5sum $(basename "$src_url")" >> "src/host/root/sources/$repo.md5"

# Create package file.
cat << EOF > "src/lfs/packages/$repo/$pkg_name.pkg"
# vim: filetype=sh
# shellcheck shell=bash
# shellcheck disable=SC2034

name="$pkg_name"
version="$pkg_version"

source_base="\$name-\$version"

sources=(
	"/sources/\$source_base$src_ext"
)
md5sums=(
	'$md5sum'
)

build()
{
	pushd "\$SRCDIR/\$source_base" || return
		# Build commands go here
	popd || return
}
EOF

