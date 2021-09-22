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

RUN mkdir /dist

VOLUME /dist

WORKDIR /tmp

ENV DEBIAN_FRONTEND=noninteractive

COPY src/packages.txt .

RUN apt-get -y update && apt-get -y upgrade \
    && bash -c 'apt-get -y install --no-install-recommends $(<packages.txt)' \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "dash dash/sh boolean false" | debconf-set-selections \
    && dpkg-reconfigure dash \
    && groupadd lfs && useradd -s /bin/bash -g lfs -m -k /dev/null lfs

COPY --chown=lfs:lfs src/lfs_profile.sh /home/lfs/.bash_profile
COPY --chown=lfs:lfs src/lfs_rc.sh /home/lfs/.bashrc

COPY --chown=lfs:lfs src/lfs_prepare.sh /

USER lfs

COPY *.sh .

CMD bash
