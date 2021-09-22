#!/usr/bin/sh

set -euo pipefail

mkdir -pv "$LFS"/{etc,var} "$LFS"/{bin,lib,sbin}

for i in bin lib sbin; do
  ln -sv "usr/$i" "$LFS/$i"
done

case $(uname -m) in
  x86_64) mkdir -pv "$LFS/lib64";;
esac

mkdir -pv "$LFS/tools"
