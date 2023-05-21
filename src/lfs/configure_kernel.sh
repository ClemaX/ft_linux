#!/bin/bash

set -euo pipefail

SCRIPTDIR=/build

source "$SCRIPTDIR/utils/logger.sh"

ACTION="${1:-menuconfig}"

KERNEL_PKG=linux
KERNEL_BRANCH=stable
KERNEL_CONFIG="$SCRIPTDIR/packages/software/linux/kernel.config"

pushd /tmp
	info "Fetching kernel sources..."

	KERNEL_VERSION=$("$SCRIPTDIR/utils/pkg.sh" version "$KERNEL_PKG")
	SOURCE_BASE="$KERNEL_PKG-$KERNEL_BRANCH-v$KERNEL_VERSION"

	tar -xf "/cache/$SOURCE_BASE.tar"

	pushd "$SOURCE_BASE"
		cp "$KERNEL_CONFIG" .config

		info "Running '$ACTION'..."

		make "$ACTION"

		if ! diff .config "$KERNEL_CONFIG"
		then
			info "Updating '$KERNEL_CONFIG'..."

			# Replace kernel config.
			cp .config "$KERNEL_CONFIG"

			# Invalidate linux pkg cache.
			rm -rf /cache/pkg/linux
		fi
	popd

	info "Cleaning up..."

	rm -r "$SOURCE_BASE"
popd

