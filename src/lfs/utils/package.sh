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

		make headers

		# Install headers without rsync.
		find usr/include -name '.*' -delete
		rm usr/include/Makefile
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
		patch -Np1 -i "../glibc-$glibc_version-fhs-1.patch"

		mkdir -v build
		pushd build
			# Ensure that root utilities are installed into /usr/sbin.
			echo "rootsbindir=/usr/sbin" > configparms

			../configure \
				--prefix=/usr \
				--host="$LFS_TGT" \
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

# Build a compressed package.
pkg_extract() # pkg builder
{
	pkg="$1"
	builder="$2"

	base="${pkg##*/}"
	name="${base%.tar*}"

	echo "Extracting $base to $name..."
	tar xf "$pkg"

	echo "Building $name..."
	"$builder" "$name"

	sed -e "/$base/d" -i packages.lst
}
