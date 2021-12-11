NCORES=$(nproc)
export MAKEFLAGS="-j${NCORES:-1}"

# Build a compressed package.
pkg_extract() # pkg builder
{
	local pkg="$1"
	local builder="$2"

	local base="${pkg##*/}"
	local name="${base%.tar*}"

	info "Extracting $base to $name..."
	tar --no-same-owner -xf "$pkg"

	info "Building $name..."
	"$builder" "$name"
}

pkg_build_libstdc++() # name
{
	local name="$1"

	pushd "$name"
		[ -d build ] && rm -rf build

		# Link posix thread definitions.
		ln -sfv gthr-posix.h libgcc/gthr-default.h

		mkdir -v build
		pushd build
			../libstdc++-v3/configure \
				CXXFLAGS="-g -O2 -D_GNU_SOURCE" \
				--prefix=/usr \
				--disable-multilib \
				--disable-nls \
				--host="$(uname -m)-lfs-linux-gnu" \
				--disable-libstdcxx-pch

			make

			make install
		popd
	popd
}

pkg_build_gettext() # name
{
	local name="$1"

	pushd "$name"
		./configure --disable-shared

		make

		cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
	popd
}

pkg_build_bison() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--docdir="/usr/share/doc/$name"

		make

		make install
	popd
}

pkg_build_perl() # name
{
	local name="$1"

	pushd "$name"
		sh Configure -des \
			-Dprefix=/usr \
			-Dvendorprefix=/usr \
			-Dprivlib=/usr/lib/perl5/5.34/core_perl \
			-Darchlib=/usr/lib/perl5/5.34/core_perl \
			-Dsitelib=/usr/lib/perl5/5.34/site_perl \
			-Dsitearch=/usr/lib/perl5/5.34/site_perl \
			-Dvendorlib=/usr/lib/perl5/5.34/vendor_perl \
			-Dvendorarch=/usr/lib/perl5/5.34/vendor_perl

		make

		make install
	popd
}

pkg_build_python() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--enable-shared \
			--without-ensurepip

		make || :

		make install
	popd
}

pkg_build_texinfo() # name
{
	local name="$1"

	pushd "$name"
		sed -e 's/__attribute_nonnull__/__nonnull/' \
		-i gnulib/lib/malloc/dynarray-skeleton.c

		./configure --prefix=/usr

		make

		make install
	popd
}
