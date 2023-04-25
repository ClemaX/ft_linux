# shellcheck shell=bash

set -e

NCORES=$(nproc)
export MAKEFLAGS="-j${NCORES:-1}"

# Build a compressed package.
pkg_extract() # pkg builder
{
	pkg="$1"
	builder="$2"

	base="${pkg##*/}"
	name="${base%.tar*}"

	info "Extracting $base to $name..."
	tar --skip-old-files -xf "$pkg"

	info "Building $name..."
	"$builder" "$name"

	sed -e "/$base/d" -i packages.lst
}

pkg_build_binutils()
{
	pushd "$name"
		[ -d build ] && rm -rf build

		mkdir -v build
		pushd build
			../configure \
				--prefix="$LFS/tools" \
				--with-sysroot="$LFS" \
			 	--target="$LFS_TGT" \
				--disable-nls \
				--enable-gprofng=no \
				--disable-werror

			make

			make install -j1
		popd
	popd
}

pkg_build_gcc_dep() # name
{
	name="$1"

	mv -v "$name" "$GCC_DIR/${name%%-*}"
}

pkg_build_gcc() # name
{
	local glibc_version
	local name="$1"
	local libgcc gcc_include

	glibc_version=$(basename "$LFS/sources/glibc-"*.tar*)
	glibc_version=${glibc_version%%.tar.*}
	glibc_version=${glibc_version##glibc-}

	pushd "$name"
		# Set architecture specific library directory names.
		case $(uname -m) in
			x86_64)
				sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
			;;
		esac

		mkdir -v build
		pushd "build"
			../configure \
				--target="$LFS_TGT" \
				--prefix="$LFS/tools" \
				--with-glibc-version="$glibc_version" \
				--with-sysroot="$LFS" \
				--with-newlib \
				--without-headers \
				--enable-default-pie \
				--enable-default-ssp \
				--disable-nls \
				--disable-shared \
				--disable-multilib \
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

		libgcc="$("$LFS_TGT-gcc" -print-libgcc-file-name)"
		gcc_include="$(dirname "$libgcc")/install-tools/include"

		# Add the builtin limits headers to the include path.
		cat gcc/limitx.h gcc/glimits.h gcc/limity.h > "$gcc_include/limits.h"
	popd
}

pkg_build_kernel_headers() # name
{
	name="$1"

	pushd "$name"
		make mrproper

		make headers

		find usr/include -type f ! -name '*.h' -delete

		# Install headers without rsync.
		cp -rv usr/include "$LFS/usr"
	popd
}

pkg_build_glibc() # name
{
	name="$1"

	pushd "$name"
		# Create LSB-compliance and compability symbolic links.
		case $(uname -m) in
			i?86)	ln -sfv ld-linux.so.2 "$LFS/lib/ld-lsb.so.3"
			;;
			x86_64)	ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64"
					ln -sfv ../lib/ld-linux-x86-64.so.2 "$LFS/lib64/ld-lsb-x86-64.so.3"
			;;
		esac

		# Patch non-FHS compliant runtime data directories.
		patch -Np1 -i "$LFS/sources/glibc-"*-fhs-1.patch

		mkdir -v build
		pushd build
			# Ensure that root utilities are installed into /usr/sbin.
			echo "rootsbindir=/usr/sbin" > configparms

			../configure \
				--prefix=/usr \
				--host="$LFS_TGT" \
				--build="$(../scripts/config.guess)" \
				--enable-kernel=3.2 \
				--with-headers="$LFS/usr/include" \
				libc_cv_slibdir=/usr/lib

			if ! make
			then
				warning "make failed, rerunning without parallel execution!"
				make -j1
			fi

			make DESTDIR="$LFS" install

			# Fix hardcoded path in the ldd script.
			sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"
		popd
	popd
}

pkg_build_libstdc++() # name
{
	name="$1"

	local gcc_version

	gcc_version=$(basename "$LFS/sources/gcc-"*.tar*)
	gcc_version=${gcc_version%%.tar.*}
	gcc_version=${gcc_version##gcc-}

	pushd "$name"
		[ -d build ] && rm -rf build

		mkdir -v build
		pushd build
			../libstdc++-v3/configure \
				--host="$LFS_TGT" \
				--build="$(../config.guess)" \
				--prefix=/usr \
				--disable-multilib \
				--disable-nls \
				--disable-libstdcxx-pch \
				--with-gxx-include-dir="/tools/$LFS_TGT/include/c++/$gcc_version"

			make

			make DESTDIR="$LFS" install

			rm -v "$LFS/usr/lib/lib"{stdc++,stdc++fs,supc++}.la
		popd
	popd
}

pkg_build_m4() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
			--host="$LFS_TGT" \
			--build="$(build-aux/config.guess)"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_ncurses() # name
{
	name="$1"

	pushd "$name"
		# Ensure that gawk is found first.
		sed -i s/mawk// configure

		mkdir -v build
		pushd build
			# Build tic.
			../configure

			make -C include

			make -C progs tic
		popd

		# Build Ncurses.
		./configure --prefix=/usr \
			--host="$LFS_TGT" \
			--build="$(./config.guess)" \
			--mandir=/usr/share/man \
			--with-manpage-format=normal \
			--with-shared \
			--without-normal \
			--with-cxx-shared \
			--without-debug \
			--without-ada \
			--disable-stripping \
			--enable-widec

		make

		make DESTDIR="$LFS" TIC_PATH="$PWD/build/progs/tic" install

		echo "INPUT(-lncursesw)" > "$LFS/usr/lib/libncurses.so"
	popd
}

pkg_build_bash() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
			--build="$(support/config.guess)" \
			--host="$LFS_TGT" \
			--without-bash-malloc

		make

		make DESTDIR="$LFS" install

		ln -sv bash "$LFS/bin/sh"
	popd
}

pkg_build_coreutils() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
			--host="$LFS_TGT" \
			--build="$(build-aux/config.guess)" \
			--enable-install-program=hostname \
			--enable-no-install-program=kill,uptime

		make

		make DESTDIR="$LFS" install

		# Move programs to their expected locations.
		mv -v "$LFS"/usr/bin/chroot					"$LFS"/usr/sbin
		mkdir -pv "$LFS"/usr/share/man/man8
		mv -v "$LFS"/usr/share/man/man1/chroot.1	"$LFS"/usr/share/man/man8/chroot.8
		sed -i 's/"1"/"8"/'							"$LFS"/usr/share/man/man8/chroot.8
	popd
}

pkg_build_diffutils() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr --host="$LFS_TGT"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_file() # name
{
	name="$1"

	pushd "$name"
		mkdir -v build

		pushd build
			../configure --disable-bzlib \
			   --disable-libseccomp \
			   --disable-xzlib \
			   --disable-zlib

			make
		popd

		./configure --prefix=/usr --host="$LFS_TGT" --build="$(./config.guess)"

		make FILE_COMPILE="$PWD/build/src/file"

		make DESTDIR="$LFS" install

		# Remove harmful static archive.
		rm -v "$LFS/usr/lib/libmagic.la"
	popd
}

pkg_build_findutils() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
			--localstatedir=/var/lib/locate \
			--host="$LFS_TGT" \
			--build="$(build-aux/config.guess)"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_gawk() # name
{
	name="$1"

	pushd "$name"
		# Disable extras.
		sed -i 's/extras//' Makefile.in

		./configure --prefix=/usr \
			--host="$LFS_TGT" \
			--build="$(./config.guess)"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_grep() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
			--host="$LFS_TGT"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_gzip() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr --host="$LFS_TGT"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_make() # name
{
	name="$1"

	pushd "$name"
		# Fix an issue identified upstream.
		sed -e '/ifdef SIGPIPE/,+2 d' \
		-e '/undef  FATAL_SIG/i FATAL_SIG (SIGPIPE);' \
		-i src/main.c

		./configure --prefix=/usr \
			--without-guile \
			--host="$LFS_TGT" \
			--build="$(build-aux/config.guess)"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_patch() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr   \
			--host="$LFS_TGT" \
			--build="$(build-aux/config.guess)"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_sed() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr   \
			--host="$LFS_TGT"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_tar() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
			--host="$LFS_TGT" \
			--build="$(build-aux/config.guess)"

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_xz() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
			--host="$LFS_TGT" \
			--build="$(build-aux/config.guess)" \
			--disable-static \
			--docdir=/usr/share/doc/xz-5.4.1

		make

		make DESTDIR="$LFS" install

		rm -v "$LFS/usr/lib/liblzma.la"
	popd
}

pkg_build_binutils_pass2() # name
{
	name="$1"


	pushd "$name"
		# Workaround lack of sysroot support to fix library linking.
		# shellcheck disable=SC2016
		sed '6009s/$add_dir//' -i ltmain.sh

		[ -d build ] && rm -rf build

		mkdir -v build
		pushd build
			../configure \
				--prefix=/usr \
				--build="$(../config.guess)" \
				--host="$LFS_TGT" \
				--disable-nls \
				--enable-shared \
				--enable-gprofng=no \
				--disable-werror \
				--enable-64-bit-bfd

			make

			make DESTDIR="$LFS" install -j1

			# Remove harmful and unnecessary static libraries.
			rm -v "$LFS/usr/lib/lib"{bfd,ctf,ctf-nobfd,opcodes}.{a,la}
		popd
	popd
}

pkg_build_gcc_pass2() # name
{
	name="$1"

	pushd "$name"
		# Set architecture specific library directory names.
		case "$(uname -m)" in
			x86_64)
				sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
			;;
		esac

		# Allow buildiing with POSIX threads support.
		sed '/thread_header =/s/@.*@/gthr-posix.h/' \
			-i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

		# Remove existing build directory
		[ -d build ] && rm -rf build

		mkdir -v build
		pushd build
			#mkdir -pv "$LFS_TGT/libgcc"
			#ln -s ../../../libgcc/gthr-posix.h "$LFS_TGT/libgcc/gthr-default.h"

			../configure \
				--build="$(../config.guess)" \
				--host="$LFS_TGT" \
				--target="$LFS_TGT" \
				LDFLAGS_FOR_TARGET="-L$PWD/$LFS_TGT/libgcc" \
				--prefix=/usr \
				--with-build-sysroot="$LFS" \
				--enable-default-pie \
				--enable-default-ssp \
				--disable-nls \
				--disable-multilib \
				--disable-libatomic \
				--disable-libgomp \
				--disable-libquadmath \
				--disable-libssp \
				--disable-libvtv \
				--enable-languages=c,c++

			make

			make DESTDIR="$LFS" install

			ln -sv gcc "$LFS/usr/bin/cc"
		popd
	popd
}
