#!/bin/bash

set -euo pipefail

# Create the bases folder structure
mkdir -pv "$LFS"/{etc,var} "$LFS"/usr/{bin,lib,sbin}

# Link the bin lib and sbin directories to their /usr/... counterparts.
for i in bin lib sbin; do
  ln -sv "usr/$i" "$LFS/$i"
done

# Create architecture specific directories.
case $(uname -m) in
  x86_64) mkdir -pv "$LFS/lib64";;
esac

mkdir -pv "$LFS/tools"
