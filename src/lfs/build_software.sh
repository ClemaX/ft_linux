#!/usr/bin/env bash

set -eEu

ERROR_LOG=

error_handler()
{
	local src=$1
	local lineno=$2
	local cmd=$3

	error "$src:$lineno: $cmd returned with unexpected exit status $?"

	[ -z "$ERROR_LOG" ] || tail "$ERROR_LOG"
}

trap 'error_handler "${BASH_SOURCE[0]}" "$LINENO" "$BASH_COMMAND"' ERR

SCRIPTDIR=/build

source "$SCRIPTDIR/utils/logger.sh"
source "$SCRIPTDIR/utils/package.sh"

install_pkg() # [pkg...]
{
	for pkg in "$@"
	do
		debug "Building $pkg..."
		"$SCRIPTDIR/utils/pkg.sh" build "$pkg"

		debug "Installing $pkg..."
		"$SCRIPTDIR/utils/pkg.sh" install "$pkg"

		echo
	done
}

rebuild_pkg() # pkg label
{
	local pkg="$1"
	local label="$2"

	# Move previous cached package.
	mv -v "/var/cache/pkg/$pkg"{,-no-"$label"}

	# Use rebuilt cached package if it exists.
	[ -e "/var/cache/pkg/$pkg-$label" ] \
	&& mv -v "/var/cache/pkg/$pkg"{-"$label",}

	# Reinstall package.
	install_pkg "$pkg"

	# Move rebuilt cached package.
	mv -v "/var/cache/pkg/$pkg"{,-"$label"}

	# Restore previous cached package.
	mv -v "/var/cache/pkg/$pkg"{-no-"$label",}
}

info "Creating /etc/fstab..."

dev_root_id="PARTUUID=$(findmnt / -no PARTUUID)"
dev_swap_id="${DEV_SWAP_ID:-#<swap_device>}"

column -t > /etc/fstab << EOF
#file-system 	mount-point	type		options				dump	fsck-order
$dev_root_id	/			ext4		defaults			1		1
$dev_swap_id	swap		swap		pri=1				0		0
proc			/proc		proc		nosuid,noexec,nodev	0		0
sysfs			/sys		sysfs		nosuid,noexec,nodev	0		0
devpts			/dev/pts	devpts		gid=5,mode=620		0		0
tmpfs			/run		tmpfs		defaults			0		0
devtmpfs		/dev		devtmpfs	mode=0755,nosuid	0		0
tmpfs			/dev/shm	tmpfs		nosuid,nodev		0		0
EOF

info "Installing basic system software..."
pushd "$SCRIPTDIR/packages/software"
	install_pkg man-pages iana-etc glibc zlib bzip2 xz zstd file readline m4 \
		bc flex tcl expect dejagnu binutils gmp mpfr mpc attr acl libcap \
		shadow gcc pkg-config ncurses sed psmisc gettext bison grep bash \
		libtool gdbm gperf expat inetutils less perl xml-parser intltool \
		autoconf automake openssl kmod elfutils libffi python wheel ninja \
		meson coreutils check diffutils gawk findutils groff gzip iproute2 kbd \
		libpipeline make patch tar texinfo vim eudev man-db procps-ng \
		util-linux e2fsprogs sysklogd sysvinit lfs-bootscripts
popd


info "Installing beyond LFS software..."
pushd "$SCRIPTDIR/packages/blfs"
	# Install pam.
	install_pkg libtirpc pam

	# Rebuild shadow with pam.
	pushd "$SCRIPTDIR/packages/software"
		rebuild_pkg shadow pam
	popd

	# Install useful utilities.
	install_pkg shadow-pam unifont mandoc efivar popt efibootmgr libpng which \
		libssh2 libxml2 libxslt libarchive libuv nghttp2 libtasn1 p11-kit \
		fcron make-ca curl git cmake llvm rustc gptfdisk pciutils acpid dhcpcd \
		pcre2 graphite2 freetype glib gobject-introspection harfbuzz unzip \
		sgml-common docbook-xml docbook-xsl-nons xmlto lynx

	# Rebuild freetype with harfbuzz.
	rebuild_pkg freetype harfbuzz

	install_pkg grub

	# Prepare Xorg build environment.
	cat > /etc/profile.d/xorg.sh << EOF
XORG_PREFIX="${XORG_PREFIX:-/usr}"
XORG_CONFIG="--prefix=\$XORG_PREFIX --sysconfdir=/etc --localstatedir=/var \
	--disable-static"

export XORG_PREFIX XORG_CONFIG
EOF

	chmod 644 /etc/profile.d/xorg.sh

	# Load rustc and xorg profiles.
	# shellcheck source=/dev/null
	export USER=root
	set +eEu
		source /etc/profile
	set -eEu

	# Install Xorg and useful applications.
	install_pkg libxcvt pixman util-macros fontconfig xcb-proto xorgproto \
		libxdmcp libxau libxcb xtrans libx11 libxext libfs libice libsm \
		libxscrnsaver libxt libxmu libxpm libxaw libxfixes libxcomposite \
		libxrender libxcursor libxdamage libfontenc libxfont2 libxft libxi \
		libxinerama libxrandr libxres libxtst libxv libxvmc libxxf86dga \
		libxxf86vm libdmx libpciaccess libxkbfile libxshmfence libdrm \
		markupsafe mako xcb-util xcb-util-image xcb-util-keysyms \
		xcb-util-renderutil xcb-util-wm xcb-util-cursor mesa xbitmaps \
		xorg-applications xcursor-themes xorg-font-util xorg-fonts-encodings \
		xorg-fonts xkeyboard-config libepoxy xorg-server xterm xinit \
		libevdev mtdev libinput xf86-input-libinput startup-notification \
		libxkbcommon cairo fribidi pango duktape dbus elogind polkit \
		alsa-lib libsndfile pulseaudio libnl cbindgen dbus-glib libjpeg-turbo \
		shared-mime-info gsettings-desktop-schemas at-spi2-core gdk-pixbuf \
		librsvg gtk3 adwaita-icon-theme libogg libvorbis libcanberra \
		notification-daemon libnotify c-ares icu nodejs sqlite yasm nspr \
		libevent libvpx libwebp nasm nss xdg-utils desktop-file-utils

	# Rebuild python with sqlite.
	rebuild_pkg python sqlite

	install_pkg firefox
popd

# TODO: Install polkit authentication agent

info "Installing extra software..."
pushd "$SCRIPTDIR/packages/extras"
	install_pkg dialog lfs-config xcb-util-xrm yajl libev libconfuse i3status \
		dracula-xresources dex i3 spice-protocol spice-vdagent spice-randr \
		alacritty dracula-alacritty
popd

# TODO: Install pkg using pkg
pushd "$SCRIPTDIR/utils"
	debug "Installing pkg script..."
	install -vm755 pkg.sh /usr/bin/pkg
popd

info "Generating initial udev rules..."

bash /usr/lib/udev/init-net-rules.sh

pushd /tmp
	if [ "$STRIP_BINARIES" = true ]
	then
		# shellcheck disable=SC2207
		save_usrlib=(
			$(cd /usr/lib; ls ld-linux*[^g])
			libc.so.6
			libthread_db.so.1
			libquadmath.so.0.0.0
			libstdc++.so.6.0.30
			libitm.so.1.0.0
			libatomic.so.1.2.0
		)

		online_usrbin=(
			bash
			find
			strip
		)

		# shellcheck disable=SC2207
		online_usrlib=(
			libbfd-2.40.so
			libsframe.so.0.0.0
			libhistory.so.8.2
			libncursesw.so.6.4
			libm.so.6
			libreadline.so.8.2
			libz.so.1.2.13
			$(cd /usr/lib; find libnss*.so* -type f)
		)

		info "Stripping binaries..."

		pushd /usr/lib
			for library in "${save_usrlib[@]}"
			do
				objcopy --only-keep-debug "$library" "$library.dbg"
				cp "$library" "/tmp/$library"
				strip --strip-unneeded "/tmp/$library"
				objcopy --add-gnu-debuglink="$library.dbg" "/tmp/$library"
				install -vm755 "/tmp/$library" /usr/lib
				rm "/tmp/$library"
			done

			for binary in "${online_usrbin[@]}"
			do
				cp "/usr/bin/$binary" "/tmp/$binary"
				strip --strip-unneeded "/tmp/$binary"
				install -vm755 "/tmp/$binary" /usr/bin
				rm "/tmp/$binary"
			done

			for library in "${online_usrlib[@]}"
			do
				cp "/usr/lib/$library" "/tmp/$library"
				strip --strip-unneeded "/tmp/$library"
				install -vm755 "/tmp/$library" /usr/lib
				rm "/tmp/$library"
			done

			for file in $(find /usr/lib -type f -name '*.so*' ! -name '*dbg') \
					$(find /usr/lib -type f -name '*.a') \
					$(find /usr/{bin,sbin,libexec} -type f)
			do
				case "${online_usrbin[*]} ${online_usrlib[*]} ${save_usrlib[*]}" in
					*$(basename "$file")* )
						;;
					* )	strip --strip-unneeded "$file" || :
						;;
				esac
			done
		popd

		unset binary library save_usrlib online_usrbin online_usrlib
	fi

	info "Cleaning up..."

	# Remove temporary build files.
	rm -rf /tmp/*

	# Remove libtool archives.
	find /usr/lib /usr/libexec -name '*.la' -delete

	# Remove the temporary compiler.
	find /usr -depth -name "$(uname -m)-lfs-linux-gnu*" -print0 \
	| xargs -0 rm -rf --

	# Remove the temporary test user.
	userdel -r tester

	info "Building the Linux kernel..."

	# Build and install the linux kernel.
	pushd "$SCRIPTDIR/packages/software"
		install_pkg linux
	popd

	# Remove sources.
	rm -rf /sources

	# Set LFS release version.
	echo "$LFS_VERSION" > /etc/lfs-release

	# Set LSB release info.
	cat > /etc/lsb-release << EOF
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="$LFS_VERSION"
DISTRIB_CODENAME="chamada"
DISTRIB_DESCRIPTION="Linux From Scratch, built by chamada"
EOF

	# Set OS release info.
	cat > /etc/os-release << EOF
NAME="Linux From Scratch"
VERSION="$LFS_VERSION"
ID=lfs
PRETTY_NAME="Linux From Scratch $LFS_VERSION"
VERSION_CODENAME="chamada"
EOF
popd
