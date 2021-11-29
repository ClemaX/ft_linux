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

	sed -e "/$base/d" -i packages.lst
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
				--host=$(uname -m)-lfs-linux-gnu \
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
