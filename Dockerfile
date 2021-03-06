FROM debian:bullseye-slim

# Prevent interaction (do not change)
ENV DEBIAN_FRONTEND=noninteractive

RUN mkdir /dist
VOLUME /dist

WORKDIR /root

COPY src/host/root/packages.lst		.
COPY src/host/root/prepare.sh		.

# LFS root
ENV LFS=/mnt/lfs

RUN ./prepare.sh && rm -f packages.lst ./prepare.sh

#COPY src/host/version-lock.sh .

COPY src/host/root/utils			./utils
COPY src/host/root/build.sh			./
COPY src/lfs						./chroot

COPY --chown=lfs:lfs src/host/lfs/	/home/lfs

# Loop device
ENV LOOP_DEV=/dev/loop0

# LFS version (use "stable" for latest)
ENV LFS_VERSION=11.0
# Linux kernel repository and version
ENV KERNEL_SOURCE="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git:v4.9.283"

# Groff page size
ENV PAGE=A4

# Compile libraries optimized for the host processor (use "true" to enable)
ENV HOST_OPTIMIZE=false

# Password for the root user
ENV ROOT_PASSWORD=toor

# Skip test suites
ENV SKIP_TESTS=true

# Strip unnecessary symbols off binaries
ENV STRIP_BINARIES=true

# Image destination
ENV IMG_DST=/dist/disk.img
# Image size in MiB
ENV IMG_SIZE=4096

CMD ./build.sh
