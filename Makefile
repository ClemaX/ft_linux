SRCDIR=src

VERBOSE=## Assign a value to verbose to enable logging.
DISTDIR=dist## The image's destination directory.
DISTVOL=lfs-dist## The destination docker-volume.
CACHEVOL=lfs-cache## The cache docker-volume.
NAME=lfs.img## The name of the image.

CAPS=SYS_ADMIN MKNOD CHOWN SETGID SETUID SYS_CHROOT FOWNER DAC_OVERRIDE## Capabilities to enable for the docker container.
CMD=./build.sh## Command to run in the docker container.

all: $(DISTDIR)/$(NAME) ## Alias for dist/lfs.img.

help:
	@grep -e '^.*:.*##\s\+.*$$' -e '^.*=.*##\s\+.*$$' Makefile \
	| sed -e 's/\(.*\):.*##\s*\(.*\)/\1:\2/' \
		-e 's/\(.*\)=\(.*\)##\s*\(.*\)/\1:\3 Defaults to "\2"./' \
	| column -t -s':'

ft_linux: $(SRCDIR) ## Build the host docker image.
	@echo "BUILD ft_linux"
	docker build -t ft_linux .

$(DISTDIR):
	@echo "MKDIR $(DISTDIR)"
	mkdir -p "$(DISTDIR)"

$(DISTDIR)/$(NAME): ft_linux $(DISTDIR) ## Build the LFS image.
	@echo "RUN $(CMD)"
	docker run --rm \
		--cap-drop=all $(CAPS:%=--cap-add=%) \
		--device-cgroup-rule='b 7:* rmw' \
		--device-cgroup-rule='b 259:* rmw' \
		-v /dev:/hostdev:ro \
		-v "$(DISTVOL):/dist:rw" \
		-v "$(CACHEVOL):/cache:rw" \
		-v "$(PWD)/$(SRCDIR)/lfs:/root/chroot" \
		--name=ft_linux \
		-it ft_linux $(CMD)

	@echo "CP $(NAME) $(DISTDIR)"
	docker run --rm -d \
		--cap-drop=all \
		-v "$(DISTVOL):/dist:rw" \
		--name=ft_linux-dist \
		ft_linux \
		tail -f /dev/null

	docker cp --quiet=false ft_linux-dist:/dist/disk.img \
		$(DISTDIR)/$(NAME) 2>&1 \
	| awk '{printf "\r%s", $$0; fflush();}'

	docker stop ft_linux-dist

	printf '\a'

check-scripts:
	shellcheck $(shell find $(SRCDIR) -type f -name '*.sh')

.PHONY: help ft_linux check-scripts

$(VERBOSE).SILENT:
