#!/bin/bash

set -eou pipefail

DIST_DIR="$PWD/dist"

docker build -t ft_linux .

# Stage 1

# SYS_ADMIN is needed for filesystem ioctl calls
# MKNOD is needed to create block devices (special files)
# -v /dev:/tmp/dev? I do not know why it is needed, but I can't format loop partitions otherwise...

docker run --rm \
    --cap-drop=all --cap-add=SYS_ADMIN --cap-add=MKNOD \
    --device-cgroup-rule='b 7:* rmw' \
    --device-cgroup-rule='b 259:* rmw' \
    -v /dev:/tmp/dev:ro \
    -v "$DIST_DIR:/dist:rw" \
    -it ft_linux bash #./image-format.sh
