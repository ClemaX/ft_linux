NCORES=$(nproc)
export MAKEFLAGS="-j${NCORES:-1}"

make() # [arg]...
{
	if ! command make $@
	then
		local CALLER="${FUNCNAME[1]}"
		warning "make failed, rerunning without parallel execution!"

		command make -j1 $@
	fi
}

# Build a compressed package.
pkg_extract() # pkg builder
{
	local pkg="$1"
	local builder="$2"

	local base="${pkg##*/}"
	local name=$(tar -tf "$pkg" | head -n1)

	name="${name%%/*}"

	info "Extracting $base to $name..."
	tar --no-same-owner --skip-old-files -xf "$pkg"

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

pkg_build_Python() # name
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

pkg_build_util-linux() # name
{
	local name="$1"

	pushd "$name"
		mkdir -pv /var/lib/hwclock

		./configure \
			ADJTIME_PATH=/var/lib/hwclock/adjtime \
			--libdir=/usr/lib \
			--docdir=/usr/share/doc/util-linux-2.37.2 \
			--disable-chfn-chsh \
			--disable-login \
			--disable-nologin \
			--disable-su \
			--disable-setpriv \
			--disable-runuser \
			--disable-pylibmount \
			--disable-static \
			--without-python \
			runstatedir=/run

		make

		make install
	popd
}

pkg_build_man-pages() # name
{
	local name="$1"

	pushd "$name"
		make prefix=/usr install
	popd
}

pkg_build_iana-etc() # name
{
	local name="$1"

	pushd "$name"
		cp -v services protocols /etc
	popd
}

pkg_build_glibc() # name
{
	local name="$1"

	pushd "$name"
		# Fix a security problem identified upstream.
		sed -e '/NOTIFY_REMOVED)/s/)/ \&\& data.attr != NULL)/' \
			-i sysdeps/unix/sysv/linux/mq_notify.c

		# Patch non-FHS compliant /var/db directory
		patch -Np1 -i /sources/glibc-2.34-fhs-1.patch

		mkdir -v build
		pushd build
			echo "rootsbindir=/usr/sbin" > configparms

			../configure \
				--prefix=/usr \
				--disable-werror \
				--enable-kernel=3.2 \
				--enable-stack-protector=strong \
				--with-headers=/usr/include \
				libc_cv_slibdir=/usr/lib

			make

			make check || warning "$name tests were not fully passed!"

			touch /etc/ld.so.conf

			# Remove an unneeded sanity check that fails in a partial environment.
			sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

			make install

			# Fix hardcoded path to the executable loader.
			sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

			# Install the configuration file and runtime directory for nscd.
			cp -v ../nscd/nscd.conf /etc/nscd.conf

			# Initialize locales.
			mkdir -pv /usr/lib/locale

			localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
			localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
			localedef -i de_DE -f ISO-8859-1 de_DE
			localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
			localedef -i de_DE -f UTF-8 de_DE.UTF-8
			localedef -i el_GR -f ISO-8859-7 el_GR
			localedef -i en_GB -f ISO-8859-1 en_GB
			localedef -i en_GB -f UTF-8 en_GB.UTF-8
			localedef -i en_HK -f ISO-8859-1 en_HK
			localedef -i en_PH -f ISO-8859-1 en_PH
			localedef -i en_US -f ISO-8859-1 en_US
			localedef -i en_US -f UTF-8 en_US.UTF-8
			localedef -i es_ES -f ISO-8859-15 es_ES@euro
			localedef -i es_MX -f ISO-8859-1 es_MX
			localedef -i fa_IR -f UTF-8 fa_IR
			localedef -i fr_FR -f ISO-8859-1 fr_FR
			localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
			localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
			localedef -i is_IS -f ISO-8859-1 is_IS
			localedef -i is_IS -f UTF-8 is_IS.UTF-8
			localedef -i it_IT -f ISO-8859-1 it_IT
			localedef -i it_IT -f ISO-8859-15 it_IT@euro
			localedef -i it_IT -f UTF-8 it_IT.UTF-8
			localedef -i ja_JP -f EUC-JP ja_JP
			localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
			localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
			localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
			localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
			localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
			localedef -i se_NO -f UTF-8 se_NO.UTF-8
			localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
			localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
			localedef -i zh_CN -f GB18030 zh_CN.GB18030
			localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
			localedef -i zh_TW -f UTF-8 zh_TW.UTF-8

			make
		popd
	popd
}

pkg_build_zlib() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		make check

		make install

		# Remove static library.
		rm -fv /usr/lib/libz.a
	popd
}

pkg_build_bzip2() # name
{
	local name="$1"

	pushd "$name"
		# Patch to install documentation.
		patch -Np1 -i /sources/bzip2-1.0.8-install_docs-1.patch

		# Ensure that symbolic links are relative.
		sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile

		# Ensure that man-pages are installed into the correct location.
		sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

		# Prepare dynamically linked compilation.
		make -f Makefile-libbz2_so
		make clean

		make

		make PREFIX=/usr install

		# Install shared library.
		cp -av libbz2.so.* /usr/lib
		ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so

		# Install shared multi-function binary.
		cp -v bzip2-shared /usr/bin/bzip2
		for i in /usr/bin/{bzcat,bunzip2}; do
			ln -sfv bzip2 $i
		done

		# Remove static library.
		rm -fv /usr/lib/libbz2.a
	popd
}

pkg_build_xz() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--docdir=/usr/share/doc/xz-5.2.5

		make

		make check

		make install
	popd
}

pkg_build_zstd() # name
{
	local name="$1"

	pushd "$name"
		make

		make prefix=/usr install

		# Remove static library.
		rm -v /usr/lib/libzstd.a
	popd
}

pkg_build_file() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		make check

		make install
	popd
}

pkg_build_readline() # name
{
	local name="$1"

	pushd "$name"
		# Prevent keeping reinstalled libraries.
		sed -i '/MV.*old/d' Makefile.in
		sed -i '/{OLDSUFF}/c:' support/shlib-install

		./configure \
			--prefix=/usr \
			--disable-static \
			--with-curses \
			--docdir=/usr/share/doc/readline-8.1

		make SHLIB_LIBS="-lncursesw"

		make SHLIB_LIBS="-lncursesw" install

		# Install documentation.
		install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.1
	popd
}

pkg_build_m4() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		make check

		make install
	popd
}

pkg_build_bc() # name
{
	local name="$1"

	pushd "$name"
		CC=gcc ./configure --prefix=/usr -G -O3

		make

		make test

		make install
	popd
}

pkg_build_flex() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr \
			--docdir=/usr/share/doc/flex-2.6.4 \
			--disable-static

		make

		make check

		make install

		# Link to lex for backward compatibility.
		ln -sv flex /usr/bin/lex
	popd
}

pkg_build_tcl() # name
{
	local name="$1"

	pushd "$name"
		# Unpack documentation.
		tar --no-same-owner -xf "/sources/$name-html.tar.gz" --strip-components=1

		local srcdir="$PWD"

		pushd unix
			./configure \
				--prefix=/usr \
				--mandir=/usr/share/man \
				$([ "$(uname -m)" = x86_64 ] && echo --enable-64bit)

			make

			# Replace build directory with install location in config files.
			sed -e "s|$srcdir/unix|/usr/lib|" \
				-e "s|$srcdir|/usr/include|" \
				-i tclConfig.sh

			sed -e "s|$srcdir/unix/pkgs/tdbc1.1.2|/usr/lib/tdbc1.1.2|" \
				-e "s|$srcdir/pkgs/tdbc1.1.2/generic|/usr/include|" \
				-e "s|$srcdir/pkgs/tdbc1.1.2/library|/usr/lib/tcl8.6|" \
				-e "s|$srcdir/pkgs/tdbc1.1.2|/usr/include|" \
				-i pkgs/tdbc1.1.2/tdbcConfig.sh

			sed -e "s|$srcdir/unix/pkgs/itcl4.2.1|/usr/lib/itcl4.2.1|" \
				-e "s|$srcdir/pkgs/itcl4.2.1/generic|/usr/include|" \
				-e "s|$srcdir/pkgs/itcl4.2.1|/usr/include|" \
				-i pkgs/itcl4.2.1/itclConfig.sh

			make test

			make install

			# Enable user write to enable stripping of debugging symbols.
			chmod -v u+w /usr/lib/libtcl8.6.so

			# Install development headers.
			make install-private-headers

			# Link default tclsh to the installed version.
			ln -sfv tclsh8.6 /usr/bin/tclsh

			# Solve conflict with a Perl man-page.
			mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
		popd
	popd
}

pkg_build_expect() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--with-tcl=/usr/lib \
			--enable-shared \
			--mandir=/usr/share/man \
			--with-tclinclude=/usr/include

		make

		make test

		make install

		ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
	popd
}

pkg_build_dejagnu() # name
{
	local name="$1"

	pushd "$name"
		mkdir -v build
		pushd build
			../configure --prefix=/usr

			# Render info files.
			makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
			makeinfo --plaintext -o doc/dejagnu.txt ../doc/dejagnu.texi

			make install

			# Install documentation.
			install -v -dm755  /usr/share/doc/dejagnu-1.6.3
			install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3

			make check
		popd
	popd
}

pkg_build_binutils() # name
{
	local name="$1"

	pushd "$name"
		# Ensure that PTYs are working correctly.
		local expected='spawn ls'
		local actual=$(expect -c "$expected")

		if [ "$actual" != "$expected" ]
		then
			debug "PTYs do not work correctly, applying upstream patch..."
			patch -Np1 -i /sources/binutils-2.37-upstream_fix-1.patch
		fi

		# Remove empty man-pages so that they are regenerated correctly.
		sed -i '63d' etc/texi2pod.pl
		find -name '*.1' -delete

		mkdir -v build
		pushd build
			../configure \
				--prefix=/usr \
				--enable-gold \
				--enable-ld=default \
				--enable-plugins \
				--enable-shared \
				--disable-werror \
				--enable-64-bit-bfd \
				--with-system-zlib

			make tooldir=/usr

			local check_log="/tmp/$name-check.log"

			# Run tests and store output.
			(command make -k check || :) 2>&1 | tee "$check_log" >&2

			# Count failed tests.
			local fail_count=$(grep -c '^FAIL: ' "$check_log")

			# Four zlib related tests are known to fail.
			if [ "$((fail_count -= 4))" -ne 0 ]
			then
				error "$check_log: $fail_count mandatory tests failed!"
				return 1
			fi

			# Remove log.
			rm -f "$check_log"

			make tooldir=/usr install -j1

			# Remove static libraries.
			rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
		popd
	popd
}

pkg_build_gmp() # name
{
	local name="$1"

	pushd "$name"
		local optimize="${HOST_OPTIMIZE:-false}"

		if [ "$optimize" != "true" ]
		then
			debug "Disabling host processor optimization..."
			cp -v configfsf.guess config.guess
			cp -v configfsf.sub config.sub
		fi

		./configure \
			--prefix=/usr \
			--enable-cxx \
			--disable-static \
			--docdir=/usr/share/doc/gmp-6.2.1

		make

		# Generate HTML documentation.
		make html

		# Run tests and store output.
		local check_log="/tmp/$name-check.log"

		command make check 2>&1 | tee "$check_log" >&2

		local pass_count=$(awk '/# PASS:/{total+=$3} ; END{print total}' "$check_log")
		local fail_count=$((197 - pass_count))

		if [ "$fail_count" -ne 0 ]
		then
			error "$check_log: $fail_count mandatory tests failed!"
			return 1
		fi

		rm -f "$check_log"

		make install
		make install-html
	popd
}

pkg_build_mpfr() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--enable-thread-safe \
			--docdir=/usr/share/doc/mpfr-4.1.0

		make

		# Generate HTML documentation.
		make html

		make check

		make install
		make install-html
	popd
}

pkg_build_mpc() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--docdir=/usr/share/doc/mpc-1.2.1

		make
		make html

		make check

		make install
		make install-html
	popd
}

pkg_build_attr() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--sysconfdir=/etc \
			--docdir=/usr/share/doc/attr-2.5.1

		make

		make check

		make install
	popd
}

pkg_build_acl() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--docdir=/usr/share/doc/acl-2.3.1

		make

		# TODO: make check after installing coreutils
		make install
	popd
}

pkg_build_libcap() # name
{
	local name="$1"

	pushd "$name"
		# Prevent static library installation.
		sed -i '/install -m.*STA/d' libcap/Makefile

		make prefix=/usr lib=lib

		make test

		make prefix=/usr lib=lib install

		# Adjust permissions of shared libraries.
		chmod -v 755 /usr/lib/lib{cap,psx}.so.2.53
	popd
}

pkg_build_shadow() # name
{
	local name="$1"

	pushd "$name"
		# Prevent groups program and man-pages installation, to use coreutils.
		sed -i 's/groups$(EXEEXT) //' src/Makefile.in
		find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
		find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
		find man -name Makefile.in -exec sed -i 's/passwd\.5 / /' {} \;

		# Use SHA-512 instead of default crypt for password encryption.
		# Change the obsolete /var/spool/mail to /var/mail.
		# Remove /bin and /sbin symlinks from PATH.
		sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD SHA512:' \
			-e 's:/var/spool/mail:/var/mail:' \
			-e '/PATH=/{s@/sbin:@@;s@/bin:@@}' \
			-i etc/login.defs

		# TODO: Think about adding cracklib support.

		# Fix a programming error.
		sed -e "224s/rounds/min_rounds/" -i libmisc/salt.c

		touch /usr/bin/passwd
		./configure \
			--sysconfdir=/etc \
			--with-group-name-max-length=32

		make

		make exec_prefix=/usr install

		make -C man install-man

		mkdir -p /etc/default
		useradd -D --gid 999

		# Enable shadowed passwords.
		pwconv
		grpconv

		# Make the shadow file writeable by the root user.
		chmod -v 600 /etc/shadow

		# Set default root password.
		chpasswd <<< "root:$ROOT_PASSWORD"
	popd
}

pkg_build_gcc() # name
{
	local name="$1"

	pushd "$name"
		# Fix an issue breaking libasan when building with glibc 2.34.
		sed -e '/static.*SIGSTKSZ/d' \
			-e 's/return kAltStackSize/return SIGSTKSZ * 4/' \
			-i libsanitizer/sanitizer_common/sanitizer_posix_libcdep.cpp

		# Set architecture specific library directory names.
		case $(uname -m) in
			x86_64)
				sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
			;;
		esac

		# Remove existing build directory
		[ -d build ] && rm -rfv build

		mkdir -v build
		pushd "build"
			../configure \
				--prefix=/usr \
				LD=ld \
				--enable-languages=c,c++ \
				--disable-multilib \
				--disable-bootstrap \
				--with-system-zlib

			make

			# Increase stack size to permit exhaustive tests.
			local prev_stack_limit=$(ulimit -s)
			ulimit -s 32768

			# Run the tests using an unprivileged user.
			chown -Rv tester .
			su tester -c "PATH=$PATH make -k check"
			# TODO: Eight tests related to analyzer are known to fail.

			# Restore stack size limit.
			ulimit -s "$prev_stack_limit"

			make install

			# Remove unneeded directory.
			rm -rf "/usr/lib/gcc/$(gcc -dumpmachine)/11.2.0/include-fixed/bits/"

			# Restore root permissions on installed headers.
			chown -v -R root:root \
				/usr/lib/gcc/*linux-gnu/11.2.0/include{,-fixed}

			# Create historical symlink required by FHS.
			ln -svr /usr/bin/cpp /usr/lib

			# Create compatibility symlink to enable Link Time Optimization.
			ln -sfv "../../libexec/gcc/$(gcc -dumpmachine)/11.2.0/liblto_plugin.so" \
				/usr/lib/bfd-plugins/

			# Compilation test.
			local check_log=/tmp/dummy.log

			echo 'int main(){}' > dummy.c
			cc dummy.c -v -Wl,--verbose &> "$check_log"
			readelf -l a.out | grep ': /lib'
			# TODO: Check output of the last command.

			local success_count=$(grep -c '/usr/lib.*/crt[1in].*succeeded' "$check_log")
			if [ "$success_count" -ne 3 ]
			then
				error "Basic compilation failed!"
				return 1
			fi

			grep -B4 '^ /usr/include' dummy.log

			# TODO: Remove or complete these tests.

			rm -v dummy.c a.out "$check_log"

			# Move a misplaced file.
			mkdir -pv /usr/share/gdb/auto-load/usr/lib
			mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
		popd
	popd
}

pkg_build_grub() # name
{
	pushd "$name"
		mkdir -vp /boot/EFI

		# Mount ESP to /boot.
		cat >> /etc/fstab << EOF
/dev/sda1 /boot vfat defaults 0 1
efivarfs /sys/firmware/efi/efivars efivarfs defaults 0 0
EOF
		grub-install --no-nvram --recheck

		# Create grub config.
		cat > /boot/grub/grub.cfg << EOF
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod part_gpt
insmod ext2
set root=(hd0,2)

if loadfont /boot/grub/fonts/unicode.pf2; then
  set gfxmode=auto
  insmod all_video
  terminal_output gfxterm
fi

menuentry "GNU/Linux, Linux 5.10.17-lfs-10.1"  {
  linux   /boot/vmlinuz-5.10.17-lfs-10.1 root=/dev/sda2 ro
}

menuentry "Firmware Setup" {
  fwsetup
}
EOF
	popd
}
