FROM debian:bookworm

RUN mkdir /dist

VOLUME /dist

WORKDIR /tmp

ENV DEBIAN_FRONTEND=noninteractive

COPY packages.txt .

RUN apt-get -y update && apt-get -y upgrade \
    && bash -c 'apt-get -y install --no-install-recommends $(<packages.txt)' \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "dash dash/sh boolean false" | debconf-set-selections \
    && dpkg-reconfigure dash

COPY image-*.sh .

CMD bash
