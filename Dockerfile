FROM debian:bookworm

# Prevent interaction (do not change)
ENV DEBIAN_FRONTEND=noninteractive

RUN mkdir /dist
VOLUME /dist

WORKDIR /root

COPY src/host/packages.lst .
COPY src/host/prepare.sh .

# LFS root
ENV LFS="/mnt/lfs"

RUN ./prepare.sh && rm -f packages.lst ./prepare.sh

COPY src/host/utils ./utils
COPY src/host/build.sh .

COPY --chown=lfs:lfs src/lfs/ /home/lfs

# Loop device
ENV LOOP_DEV="/dev/loop0"
# LFS version (use "stable" for latest)
ENV LFS_VERSION="11.0"
# Image destination
ENV IMG_DST=/dist/disk.img
# Image size in megabytes
ENV IMG_SIZE=500

CMD ./build.sh
