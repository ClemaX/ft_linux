FROM debian:bookworm

# Image destination
ENV IMG_DST=/dist/disk.img
# Image size in megabytes
ENV IMG_SIZE=1000
# Loop device
ENV LOOP_DEV="/dev/loop0"
# LFS root
ENV LFS="/mnt/lfs"
# LFS version (use "stable" for latest)
ENV LFS_VERSION="11.0"
# Prevent interaction (do not change)
ENV DEBIAN_FRONTEND=noninteractive


RUN mkdir /dist
VOLUME /dist

COPY src/host .
RUN ./prepare.sh

WORKDIR /home/lfs
COPY --chown=lfs:lfs src/lfs/ .
USER lfs
RUN ./prepare.sh

CMD bash
