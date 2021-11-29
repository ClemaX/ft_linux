#!/usr/bin/env bash

set -euo pipefail

source /build/utils/logger.sh
source /build/utils/fs.sh
source /build/utils/hosts.sh
source /build/utils/user.sh

fs_hierarchy

# Link the mounted filesystems list to /etc/mtab.
ln -sv /proc/self/mounts /etc/mtab

# Init hosts list.
hosts_init

# Init user and group lists.
user_init

# Add a test user.
user_add tester 101 /bin/bash "LFS test user"
