#!/bin/bash

set -euo pipefail

glibc_version=$(ldd --version | head -n1 | cut -d" " -f2-)

# Prepare lfs file hierarchy.
lfs_prepare() # dst
{
	dst="$1"
	# Create the bases folder structure
	mkdir -pv "$dst"/{etc,var} "$dst"/usr/{bin,lib,sbin}

	# Link the bin lib and sbin directories to their /usr/... counterparts.
	for i in bin lib sbin; do
	ln -sv "usr/$i" "$dst/$i"
	done

	# Create architecture specific directories.
	case $(uname -m) in
	x86_64) mkdir -pv "$dst/lib64";;
	esac

	mkdir -pv "$dst/tools"
}

# Build a compressed package.
lfs_extract_pkg() # pkg builder
{
	pkg="$1"
	builder="$2"

	name="${pkg%%.tar*}"

	echo "Extracting $name..."
	tar -xf "$pkg"

	echo "Building $name..."
	"$builder" $name

	sed -e "/$pkg/d" -i packages.lst
}

lfs_build_binutils()
{
	pushd "$name"
		mkdir -v Build
		pushd build
			../configure
				--prefix="$LFS/tools" \
				--with-sysroot="$LFS_TGT" \
				--disable-nls \
				--disable-werror
			make
			make install -j1
		popd
	popd
}

lfs_build_gcc_dep() # name
{
	name="$1"

	mv -v "$name" "$gcc/${name%%-*}"
}

lfs_build_gcc() # name
{
	name="$1"

	pushd "$name"
		# Set architecture specific library directory names.
		case $(uname -m) in
			x86_64)
				sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
			;;
		esac

		mkdir -v build
		pushd "build"
			../configure
				--target="$LFS_TGT" \
				--prefix="$LFS/tools" \
				--with-glibc-version="$glibc_version" \
				--with-sysroot="$LFS" \
				--with-newlib \
				--without-headers \
				--enable-initfini-array \
				--disable-nls \
				--disable-shared \
				--disable-multilib \
				--disable-decimal-float \
				--disable-threads \
				--disable-libatomic \
				--disable-libgomp \
				--disable-libquadmath \
				--disable-libssp \
				--disable-libvtv \
				--disable-libstdcxx \
				--enable-languages=c,c++
			make
			make install
		popd

		libgcc=$("$LFS_TGT-gcc" -print-libgcc-file-name)
		gcc_include=$(dirname "$libgcc")/install-tools/include

		# Add the builtin limits headers to the include path.
		cat gcc/limitx.h gcc/glimits.h gcc/limity.h > "$gcc_include/limits.h"
	popd
}

lfs_build_kernel() # name
{
	name="$1"

	pushd "$name"
		make mrproper

		make headers

		# Install headers without rsync.
		find usr/include -name '.*' -delete
		rm usr/include/Makefile
		cp -rv usr/include "$LFS/usr"
	popd
}

lfs_build_glibc() # name
{
	name="$1"

	pushd "$name"
		case $(uname -m) in
			i?86)	ln -sfv ld-linux.so.2 "$LFS/lib/ld-lsb.so.3"
			;;
			x86_64)	ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64"
					ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3"
			;;
		esac

		patch -Np1 -i "../glibc-$glibc_version-fhs-1.patch"

		mkdir -v build
		pushd build
			echo "rootsbindir=/usr/sbin" > configparms
			../configure \
				--prefix=/usr \
				--host="$LFS_TGT" \
				--enable-kernel=3.2 \
				--with-headers="$LFS/usr/include" \
				libc_cv_slibdir=/usr/lib
			make
			make DESTDIR="$LFS" install

			sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"
		popd
	popd
}

lfs_prepare "$LFS"

pushd "$LFS/sources"
	ls *.tar* > packages.lst

	lfs_extract_pkg binutils*.tar* lfs_build_binutils

	gcc=gcc*.tar.*

	mkdir -v "$gcc"

	lfs_extract_pkg mpfr*.tar* lfs_build_gcc_dep
	lfs_extract_pkg gmp*.tar* lfs_build_gcc_dep
	lfs_extract_pkg mpc*.tar* lfs_build_gcc_dep

	lfs_extract_pkg gcc*.tar* lfs_build_gcc

	lfs_extract_pkg linux*.tar* lfs_build_kernel

	while read -r pkg < packages.lst
	do
		echo TODO: lfs_extract_pkg "$pkg" 
	done
popd