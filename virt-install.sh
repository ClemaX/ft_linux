#!/usr/bin/env bash

sudo virt-install --name=LFS \
	--os-variant=linux2022 \
	--vcpu=8 \
	--ram=8192 \
	--disk "path=$PWD/dist/disk.img" \
	--graphics spice \
	--network network=default \
	--import \
	--boot uefi
