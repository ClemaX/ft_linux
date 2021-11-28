FROM debian:bullseye-slim

# Prevent interaction (do not change)
ENV DEBIAN_FRONTEND=noninteractive

RUN mkdir /dist
VOLUME /dist

WORKDIR /root

COPY src/host/root/packages.lst .
COPY src/host/root/prepare.sh .

# LFS root
ENV LFS="/mnt/lfs"

RUN ./prepare.sh && rm -f packages.lst ./prepare.sh

#COPY src/host/version-lock.sh .

COPY src/host/root/utils ./utils
COPY src/host/root/build.sh .

COPY --chown=lfs:lfs src/host/lfs/ /home/lfs

# Loop device
ENV LOOP_DEV="/dev/loop0"

# LFS version (use "stable" for latest)
ENV LFS_VERSION="11.0"
# Linux kernel version
ENV LINUX_VERSION="v4.9.283"

# Image destination
ENV IMG_DST=/dist/disk.img
# Image size in megabytes
ENV IMG_SIZE=4096

CMD ./build.sh
