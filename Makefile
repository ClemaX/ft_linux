## Parameters:
## ----------
SRCDIR:=src

VERBOSE:=## Assign a value to verbose to enable logging.
DISTDIR:=dist## The image's destination directory.
DISTVOL:=lfs-dist## The destination docker-volume.
CACHEVOL:=lfs-cache## The cache docker-volume.
NAME:=lfs.img## The name of the image.
##
VIRTCPU:=8## CPU count to use for virtual machines.
VIRTRAM:=4096## RAM amount to use for virtual machines (in MB).
VIRTVRAM:=128## VRAM amount to use for virtual machines (in MiB).
VIRTNAME:=LFS## Name to use for virtual machines.
##
CAPS:=SYS_ADMIN MKNOD CHOWN SETGID SETUID SYS_CHROOT FOWNER DAC_OVERRIDE## Capabilities to enable for the docker container.
CMD:=./build.sh## Command to run in the docker container.

MAKEFILE:=$(CURDIR)/$(firstword $(MAKEFILE_LIST))

RE_SECTION:=^\s*\#\#
RE_RULE:=^.*:.*\#\#\s+
RE_VARIABLE:=^.*=.*\#\#\s+

SED_SECTION:=s/^\s*\#\#\s*(.*)/\1/
SED_RULE:=s/(.*):.*\#\#\s*(.*)/\1|\2/
SED_VARIABLE:=s/(.*)=(.*)\#\#\s*(.*)/\1|\3 Defaults to "\2"./

SED_MATCH:=$(RE_SECTION)|$(RE_RULE)|$(RE_VARIABLE)
SED_SUBST:={$(SED_SECTION);$(SED_RULE);$(SED_VARIABLE);p}


##
##
## Rules:
## -----
all: $(DISTDIR)/$(NAME) ## Alias for $(DISTDIR)/$(NAME).

##

help: ## Show available parameters and rules.
	@sed -n -E \
		-e '/$(RE_SECTION)/{$(SED_SECTION); p}' \
		-e '/$(RE_RULE)/{$(SED_RULE); p}' \
		-e '/$(RE_VARIABLE)/{$(SED_VARIABLE); p}' \
		$(MAKEFILE) \
	| column -L -t -s'|'

##

ft_linux: $(SRCDIR) ## Build the host docker image.
	@echo "BUILD ft_linux"
	docker build -t ft_linux .

$(DISTDIR):
	@echo "MKDIR $(DISTDIR)"
	mkdir -p "$(DISTDIR)"

$(DISTDIR)/$(NAME): ft_linux $(DISTDIR) ## Build the LFS image.
	if [ ! -f $(DISTDIR)/$(NAME) ] || [ ! -f "$(DISTDIR)/build-id" ] \
	   || [ "$$(cat "$(DISTDIR)/build-id")" != "$$(docker inspect -f '{{.Id}}' ft_linux)" ]; \
	then \
		set -euo pipefail; \
\
		echo "RUN $(CMD)"; \
		docker run --rm \
			--cap-drop=all $(CAPS:%=--cap-add=%) \
			--device-cgroup-rule='b 7:* rmw' \
			--device-cgroup-rule='b 259:* rmw' \
			-v /dev:/hostdev:ro \
			-v "$(DISTVOL):/dist:rw" \
			-v "$(CACHEVOL):/cache:rw" \
			-v "$(shell readlink -f "$(SRCDIR)/lfs"):/root/chroot" \
			--name=ft_linux \
			-it ft_linux $(CMD); \
\
		echo "CP $(NAME) $(DISTDIR)"; \
		docker run --rm -d \
			--cap-drop=all \
			-v "$(DISTVOL):/dist:rw" \
			--name=ft_linux-dist \
			ft_linux \
			tail -f /dev/null; \
\
		docker cp --quiet=false ft_linux-dist:/dist/disk.img \
			$(DISTDIR)/$(NAME) 2>&1 \
		| awk '{printf "\r%s", $$0; fflush();}'; echo; \
\
		echo "$$(docker inspect -f '{{.Id}}' ft_linux)" \
			> "$(DISTDIR)/build-id"; \
\
		docker stop ft_linux-dist; \
\
		printf '\a'; \
	fi

##

edit: $(DISTDIR)/$(NAME) ## Edit or inspect a built image using chroot.
	@echo "RUN ./edit.sh"
	docker run --rm \
		--cap-drop=all $(CAPS:%=--cap-add=%) \
		--device-cgroup-rule='b 7:* rmw' \
		--device-cgroup-rule='b 259:* rmw' \
		-v /dev:/hostdev:ro \
		-v "$(DISTVOL):/dist:rw" \
		-v "$(CACHEVOL):/cache:rw" \
		-v "$(shell readlink -f "$(SRCDIR)/lfs"):/root/chroot" \
		--name=ft_linux \
		-it ft_linux ./edit.sh

##

kernel-oldconfig: $(DISTDIR)/$(NAME) ## Migrate from an older kernel configuration.
	@echo "RUN kernel oldconfig"
	docker run --rm \
		--cap-drop=all $(CAPS:%=--cap-add=%) \
		--device-cgroup-rule='b 7:* rmw' \
		--device-cgroup-rule='b 259:* rmw' \
		-v /dev:/hostdev:ro \
		-v "$(DISTVOL):/dist:rw" \
		-v "$(CACHEVOL):/cache:rw" \
		-v "$(shell readlink -f "$(SRCDIR)/lfs"):/root/chroot" \
		--name=ft_linux \
		-it ft_linux ./kernel.sh oldconfig

kernel-menuconfig: $(DISTDIR)/$(NAME) ## Edit the kernel configuration interactively.
	@echo "RUN kernel menuconfig"
	docker run --rm \
		--cap-drop=all $(CAPS:%=--cap-add=%) \
		--device-cgroup-rule='b 7:* rmw' \
		--device-cgroup-rule='b 259:* rmw' \
		-v /dev:/hostdev:ro \
		-v "$(DISTVOL):/dist:rw" \
		-v "$(CACHEVOL):/cache:rw" \
		-v "$(shell readlink -f "$(SRCDIR)/lfs"):/root/chroot" \
		--name=ft_linux \
		-it ft_linux ./kernel.sh menuconfig

##

virt-install: $(DISTDIR)/$(NAME) ## Install the built image as a virt-manager VM.
	@echo "Installing '$(VIRTNAME)' using virt-install..."
	@virt-install \
		--name=LFS \
		--os-variant=linux2022 \
		--vcpu="$(VIRTCPU)" \
		--ram="$(VIRTRAM)" \
		--disk "bus=sata,path=$(shell readlink -f "$(DISTDIR)/$(NAME)")" \
		--video=qxl,vgamem="$(shell numfmt --from-unit Mi --to-unit Ki "$(VIRTVRAM)")",vram="$(shell numfmt --from-unit Mi --to-unit Ki "$(VIRTVRAM)")" \
		--channel spicevmc \
		--network network=default \
		--boot uefi \
		--import \
		--autoconsole none

virt-uninstall: ## Uninstall the virt-manager VM.
	@echo "Uninstalling '$(VIRTNAME)' using virsh..."
	@virsh undefine "$(VIRTNAME)" --nvram

$(DISTDIR)/$(NAME).vdi: $(DISTDIR)/$(NAME) ## Build a LFS VDI disk image.
	@rm -f "$(DISTDIR)/$(NAME).vdi"
	@VBoxManage convertfromraw "$(DISTDIR)/$(NAME)" "$(DISTDIR)/$(NAME).vdi"

##

vbox-install: $(DISTDIR)/$(NAME).vdi ## Install the built image as a VirtualBox VM.
	@echo "Installing '$(VIRTNAME)' using VBoxManage..."
	@VBoxManage createvm \
		--name "$(VIRTNAME)" \
		--ostype=Linux_64 \
		--register

	@VBoxManage modifyvm "$(VIRTNAME)" \
		--memory "$(VIRTRAM)" \
		--vram "$(VIRTVRAM)" \
		--graphicscontroller=vmsvga \
		--firmware=efi64

	@VBoxManage storagectl "$(VIRTNAME)" \
		--name "SATA Controller" \
		--add sata \
		--controller IntelAHCI \
		--portcount 1

	@VBoxManage storageattach "$(VIRTNAME)" \
		--storagectl "SATA Controller" \
		--port 0 \
		--device 0 \
		--type hdd \
		--medium "$(shell readlink -f "$(DISTDIR)/$(NAME).vdi")"

vbox-uninstall: ## Uninstall the VirtualBox VM.
	@echo "Uninstalling '$(VIRTNAME)' using VBoxManage..."
	@! VBoxManage list runningvms | grep "\"$(VIRTNAME)\"" > /dev/null \
	|| VBoxManage controlvm "$(VIRTNAME)" poweroff

	@VBoxManage unregistervm "$(VIRTNAME)" --delete

check-scripts:
	shellcheck $(shell find "$(SRCDIR)" -type f -name '*.sh')

.PHONY: all help ft_linux edit virt-install vbox-install vbox-uninstall \
	check-scripts

$(VERBOSE).SILENT:
