SRCDIR=src

VERBOSE=## Assign a value to verbose to enable logging.
DISTDIR=dist## The destination directory to be shared with the host.
CACHEVOL=lfs-cache## The cache docker-volume.
NAME=lfs.img## The name of the image.

CAPS=SYS_ADMIN MKNOD CHOWN SETGID SETUID SYS_CHROOT FOWNER## Capabilities to enable for the docker container.
CMD=./build.sh## Command to run in the docker container.

all: $(DISTDIR)/$(NAME) ## Alias for dist/lfs.img.

help:
	@grep -e '^.*:.*##\s\+.*$$' -e '^.*=.*##\s\+.*$$' Makefile \
	| sed -e 's/\(.*\):.*##\s*\(.*\)/\1:\2/' -e 's/\(.*\)=\(.*\)##\s*\(.*\)/\1:\3 Defaults to "\2"./' \
	| column -t -s':'

ft_linux: $(SRCDIR) ## Build the host docker image.
	@echo "BUILD ft_linux"
	@docker build -t ft_linux .

$(DISTDIR)/$(NAME): ft_linux ## Build the LFS image.
	@echo "RUN $(CMD)"
	@docker run --rm \
    --cap-drop=all $(CAPS:%=--cap-add=%) \
    --device-cgroup-rule='b 7:* rmw' \
    --device-cgroup-rule='b 259:* rmw' \
    -v /dev:/hostdev:ro \
    -v "$(shell pwd)/$(DISTDIR):/dist:rw" \
    -v "$(CACHEVOL):/cache:rw" \
    -it ft_linux $(CMD)

.PHONY: help ft_linux

$(VERBOSE).SILENT:
