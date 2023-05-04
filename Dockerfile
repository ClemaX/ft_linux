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

COPY src/host/root/sources			./sources
COPY src/host/root/utils			./utils
COPY src/host/root/build.sh			./
COPY src/lfs						./chroot

COPY --chown=lfs:lfs src/host/lfs/	/home/lfs

# Loop device
ENV LOOP_DEV=/dev/loop0

# LFS version (use "stable" for latest)
ENV LFS_VERSION=11.3
# Linux kernel repository and version
ENV KERNEL_SOURCE="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git:v6.1.11"

# Groff page size
ENV PAGE=A4

# Compile libraries optimized for the host processor (use "true" to enable)
ENV HOST_OPTIMIZE=false

# Password for the root user
ENV ROOT_PASSWORD=toor

# Default kernel version suffix and hostname
ENV LFS_LOCALVERSION=-chamada LFS_HOSTNAME=chamada

# Skip test suites
ENV SKIP_TESTS=true
# Default xz options: -T0: Use as many threads as there are processor cores.
ENV XZ_DEFAULTS="-T0"

# Strip unnecessary symbols off binaries
ENV STRIP_BINARIES=true

# Image destination and maximal size in MiB
ENV IMG_DST=/dist/disk.img IMG_SIZE=12288

# Final swap and root sizes in MiB
ENV FS_ESP_SIZE=512 FS_SWAP_SIZE=1636 FS_ROOT_SIZE=6144

CMD ./build.sh
