SRCDIR=src

VERBOSE=## Assign a value to verbose to enable logging.
DSTDIR=dist ## The destination directory to be shared with the host.
NAME=lfs.img ## The name of the image.

all: $(NAME) ## Alias for dist/lfs.img.

help:
	@grep -e '^.*:.*##\s\+.*$$' -e '^.*=.*##\s\+.*$$' Makefile \
	| sed -e 's/\(.*\):.*##\s*\(.*\)/\1:\2/' -e 's/\(.*\)=\(.*\)##\s*\(.*\)/\1:\3 Defaults to "\2"./' \
	| column -t -s':'

ft_linux: $(SRCDIR) ./build.sh ## Build the host docker image.
	@echo "BUILD ft_linux"
	@docker build -t ft_linux .

$(NAME): ft_linux ## Build the LFS image.
	@echo "RUN bash"
	@docker run --rm \
    --cap-drop=all --cap-add=SYS_ADMIN --cap-add=MKNOD \
    --device-cgroup-rule='b 7:* rmw' \
    --device-cgroup-rule='b 259:* rmw' \
    -v /dev:/tmp/dev:ro \
    -v "$(shell pwd)/$(DST_DIR):/dist:rw" \
    -it ft_linux bash #./image-format.sh

.PHONY: help ft_linux

$(VERBOSE).SILENT:
