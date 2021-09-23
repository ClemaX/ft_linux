#!/bin/bash

# TODO: Fix package pinning max versions

set -euo pipefail

# Install packages
apt-get -y update
apt-get -y upgrade
bash -c 'apt-get -y install --no-install-recommends $(<packages.lst)'

# Remove unnecessary files
apt-get clean
rm -rf /var/lib/apt/lists/*

# Use bash instead of dash
echo "dash dash/sh boolean false" | debconf-set-selections
dpkg-reconfigure dash

# Add a builder user
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs

# Create the lfs mountpoint
mkdir -pv "$LFS"
chown lfs:lfs "$LFS"
