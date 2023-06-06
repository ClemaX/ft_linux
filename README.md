# ft_linux

![Screenshot](screenshot.png)

This project aims to build a Linux system by following the [Linux From Scratch](https://www.linuxfromscratch.org/lfs/) guide.

This repository contains build scripts, as well as a docker image that can be used to run these scripts.

The build scripts install all the packages from [LFS 11.3](https://www.linuxfromscratch.org/lfs/view/11.3/). Additionally, some [BLFS](https://www.linuxfromscratch.org/blfs/) packages are provided, such as command-line utilities and the Xorg server.

## Prerequisites
- make
- docker

## Configuration
Various default settings can be configured using the docker environment variables in the `Dockerfile`.

## Building an image
To build the image, simply execute `make` in the parent directory of this repository.

The image should be stored by default at `dist/lfs.img`.

## Hardware requirements
Currently, only UEFI is supported, and Secure Boot needs to be disabled.
The resulting disk image has been tested on KVM and VirtualBox.

## Using the system
To log in, use the default credentials `root:toor`.

The default password can be changed using the docker environment variables.

The root user password can be changed at runtime using the `passwd` command.

To configure networking or expand the file-system to use the whole disk you can use the `lfs-config` command.
