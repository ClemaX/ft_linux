#!/usr/bin/env bash

set -euo pipefail

SCRIPTDIR=/build

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/fs.sh"
source "$SCRIPTDIR/utils/hosts.sh"
source "$SCRIPTDIR/utils/user.sh"

# Create the Standard filesystem hierarchy.
fs_hierarchy

# Link the mounted filesystems list to /etc/mtab.
ln -sv /proc/self/mounts /etc/mtab

# Init hosts list.
hosts_init

# Init user and group lists.
user_init

# Add a test user.
user_add tester 101 /bin/bash "LFS test user"
