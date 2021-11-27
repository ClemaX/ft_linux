NCORES=$(nproc)
export MAKEFLAGS="-j${NCORES:-1}"

pkg_build_binutils()
{
	pushd "$name"
		mkdir -v build
		pushd build
			../configure \
				--prefix="$LFS/tools" \
				--with-sysroot="$LFS" \
             	--target="$LFS_TGT" \
				--disable-nls \
				--disable-werror

			make

			make install -j1
		popd
	popd
}

pkg_build_gcc_dep() # name
{
	name="$1"

	mv -v "$name" "$gcc_dir/${name%%-*}"
}

pkg_build_gcc() # name
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
			../configure \
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

pkg_build_kernel_headers() # name
{
	name="$1"

	pushd "$name"
		make mrproper

		cp ~/kernel.config .config

		make headers_install

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
		patch -Np1 -i "$LFS/sources/glibc-2.34-fhs-1.patch"

		mkdir -v build
		pushd build
			# Ensure that root utilities are installed into /usr/sbin.
			echo "rootsbindir=/usr/sbin" > configparms

			../configure \
				--prefix=/usr \
				--host="$LFS_TGT" \
				--build=$(../scripts/config.guess) \
				--enable-kernel=3.2 \
				--with-headers="$LFS/usr/include" \
				libc_cv_slibdir=/usr/lib

			make || make -j1

			make DESTDIR="$LFS" install

			# Fix hardcoded path in the ldd script.
			sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"
		popd
	popd
}

pkg_build_libstdc++() # name
{
	name="$1"

	pushd "$name"
		[ -d build ] && rm -rfv build

		mkdir -v build
		pushd build
			../libstdc++-v3/configure \
				--host="$LFS_TGT" \
				--build="$(../config.guess)" \
				--prefix=/usr \
				--disable-multilib \
				--disable-nls \
				--disable-libstdcxx-pch \
				--with-gxx-include-dir="$LFS/tools/$LFS_TGT/include/c++/11.2.0"
			make

			make DESTDIR="$LFS" install
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

			# Build Ncurses.
			./configure --prefix=/usr \
				--host="$LFS_TGT" \
				--build="$(./config.guess)" \
				--mandir=/usr/share/man \
				--with-manpage-format=normal \
				--with-shared \
				--without-debug \
				--without-ada \
				--without-normal \
				--enable-widec

			make

			make DESTDIR="$LFS" TIC_PATH="$PWD/build/progs/tic install"

			echo "INPUT(-lncursesw)" > "$LFS/usr/lib/libncurses.so"
		popd
	popd
}

pkg_build_bash() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
            --build=$(support/config.guess) \
            --host=$LFS_TGT \
            --without-bash-malloc
		
		make

		make DESTDIR="$LFS" install

		ln -sv bash $LFS/bin/sh
	popd
}

pkg_build_coreutils() # name
{
	name="$1"

	pushd "$name"
		./configure --prefix=/usr \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess) \
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

		make DESTDIR=$LFS install
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
		./configure --prefix=/usr   \
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
            --docdir=/usr/share/doc/xz-5.2.5

		make

		make DESTDIR="$LFS" install
	popd
}

pkg_build_binutils_pass2() # name
{
	name="$1"

	pushd "$name"
		[ -d build ] && rm -rfv build

		mkdir -v build
		pushd build
			../configure \
				--prefix=/usr \
				--build="$(../config.guess)" \
				--host="$LFS_TGT" \
				--disable-nls \
				--enable-shared \
				--disable-werror \
				--enable-64-bit-bfd

			make

			make DESTDIR="$LFS" install -j1
			install -vm755 libctf/.libs/libctf.so.0.0.0 "$LFS"/usr/lib
		popd
	popd
}

pkg_build_gcc_pass2() # name
{
	name="$1"

	pushd "$name"
		[ -d build ] && rm -rfv build
		
		mkdir -v build
		pushd build
			mkdir -pv "$LFS_TGT/libgcc"
			ln -s ../../../libgcc/gthr-posix.h "$LFS_TGT/libgcc/gthr-default.h"

			../configure \
				--build="$(../config.guess)" \
				--host="$LFS_TGT" \
				--prefix=/usr \
				CC_FOR_TARGET="$LFS_TGT-gcc" \
				--with-build-sysroot="$LFS" \
				--enable-initfini-array \
				--disable-nls \
				--disable-multilib \
				--disable-decimal-float \
				--disable-libatomic \
				--disable-libgomp \
				--disable-libquadmath \
				--disable-libssp \
				--disable-libvtv \
				--disable-libstdcxx \
				--enable-languages=c,c++
			
			make

			make DESTDIR="$LFS" install

			ln -sv gcc "$LFS/usr/bin/cc"
		popd
	popd
}

# Build a compressed package.
pkg_extract() # pkg builder
{
	pkg="$1"
	builder="$2"

	base="${pkg##*/}"
	name="${base%.tar*}"

	info "Extracting $base to $name..."
	tar xf "$pkg"

	info "Building $name..."
	"$builder" "$name"

	sed -e "/$base/d" -i packages.lst
}
