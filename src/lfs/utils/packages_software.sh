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

			if [ "$SKIP_TESTS" != true ]
			then
				make check || warning "$name tests were not fully passed!"
			fi

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

			local input
			local charmap
			local output
			local options
			local cmd

			while IFS=$'\t ' read -r -a fields
			do
				[[ "${fields[*]}" =~ ^#.*$ || "${fields[*]}" =~ ^$ ]] \
					&& continue
				set -- "${fields[@]}"

				input=$1; shift
				charmap=$1; shift
				output=$1; shift
				options=("$@")

				cmd=(localedef -i "$input" -f "$charmap" "$output")

				if [ "${options[0]}" = "nofail" ]
				then
					set -- "${options[@]}"
					shift

					"${cmd[@]}" 2>/dev/null || :
				else
					"${cmd[@]}"
				fi
			done < locales.lst

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

		[ "$SKIP_TESTS" != true ] && make check

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

		[ "$SKIP_TESTS" != true ] && make check

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

		[ "$SKIP_TESTS" != true ] && make check

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

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_bc() # name
{
	local name="$1"

	pushd "$name"
		CC=gcc ./configure --prefix=/usr -G -O3

		make

		[ "$SKIP_TESTS" != true ] && make test

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

		[ "$SKIP_TESTS" != true ] && make check

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

			[ "$SKIP_TESTS" != true ] && make test

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
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--with-tcl=/usr/lib \
			--enable-shared \
			--mandir=/usr/share/man \
			--with-tclinclude=/usr/include

		make

		[ "$SKIP_TESTS" != true ] && make test

		make install

		ln -svf "expect$version/libexpect$version.so" /usr/lib
	popd
}

pkg_build_dejagnu() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		mkdir -v build
		pushd build
			../configure --prefix=/usr

			# Render info files.
			makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
			makeinfo --plaintext -o doc/dejagnu.txt ../doc/dejagnu.texi

			make install

			# Install documentation.
			install -v -dm755  "/usr/share/doc/dejagnu-$version"
			install -v -m644   doc/dejagnu.{html,txt} "/usr/share/doc/dejagnu-$version"

			[ "$SKIP_TESTS" != true ] && make check
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

			if [ "$SKIP_TESTS" != true ]
			then
				local check_log="/tmp/$name-check.log"
				local fail_count

				# Run tests and store output.
				(make -k check || :) 2>&1 | tee "$check_log" >&2

				# Count failed tests.
				fail_count=$(grep -c '^FAIL: ' "$check_log")

				# Four zlib related tests are known to fail.
				if [ "$((fail_count -= 4))" -ne 0 ]
				then
					error "$check_log: $fail_count mandatory tests failed!"
					false
				fi

				# Remove log.
				rm -f "$check_log"
			fi

			make tooldir=/usr install -j1

			# Remove static libraries.
			rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes}.a
		popd
	popd
}

pkg_build_gmp() # name
{
	local name="$1"
	local version="${name##*-}"

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
			--docdir="/usr/share/doc/gmp-$version"

		make

		# Generate HTML documentation.
		make html

		if [ "$SKIP_TESTS" != true ]
		then
			# Run tests and store output.
			local check_log="/tmp/$name-check.log"
			local pass_count
			local fail_count

			make check 2>&1 | tee "$check_log" >&2

			pass_count=$(awk '/# PASS:/{total+=$3} ; END{print total}' "$check_log")
			fail_count=$((197 - pass_count))

			if [ "$fail_count" -ne 0 ]
			then
				error "$check_log: $fail_count mandatory tests failed!"
				return 1
			fi

			rm -f "$check_log"
		fi

		make install
		make install-html
	popd
}

pkg_build_mpfr() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--enable-thread-safe \
			--docdir="/usr/share/doc/mpfr-$version"

		make

		# Generate HTML documentation.
		make html

		[ "$SKIP_TESTS" != true ] && make check

		make install
		make install-html
	popd
}

pkg_build_mpc() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--docdir="/usr/share/doc/mpc-$version"

		make
		make html

		[ "$SKIP_TESTS" != true ] && make check

		make install
		make install-html
	popd
}

pkg_build_attr() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--sysconfdir=/etc \
			--docdir="/usr/share/doc/attr-$version"

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_acl() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--docdir="/usr/share/doc/acl-$version"

		make

		# TODO: make check after installing coreutils
		make install
	popd
}

pkg_build_libcap() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		# Prevent static library installation.
		sed -i '/install -m.*STA/d' libcap/Makefile

		make prefix=/usr lib=lib

		[ "$SKIP_TESTS" != true ] && make test

		make prefix=/usr lib=lib install

		# Adjust permissions of shared libraries.
		chmod -v 755 /usr/lib/lib{cap,psx}.so."$version"
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
	local version="${name##*-}"

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
		[ -d build ] && rm -rf build

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

			if [ "$SKIP_TESTS" != true ]
			then
				# Increase stack size to permit exhaustive tests.
				local prev_stack_limit

				prev_stack_limit=$(ulimit -s)
				ulimit -s 32768

				# Run the tests using an unprivileged user.
				chown -Rv tester .
				su tester -c "PATH=$PATH make -k check"
				# TODO: Eight tests related to analyzer are known to fail.

				# Restore stack size limit.
				ulimit -s "$prev_stack_limit"
			fi

			make install

			# Remove unneeded directory.
			rm -rf "/usr/lib/gcc/$(gcc -dumpmachine)/$version/include-fixed/bits/"

			# Restore root permissions on installed headers.
			chown -v -R root:root \
				/usr/lib/gcc/*linux-gnu/"$version"/include{,-fixed}

			# Create historical symlink required by FHS.
			ln -svr /usr/bin/cpp /usr/lib

			# Create compatibility symlink to enable Link Time Optimization.
			ln -sfv "../../libexec/gcc/$(gcc -dumpmachine)/$version/liblto_plugin.so" \
				/usr/lib/bfd-plugins/

			if [ "$SKIP_TESTS" != true ]
			then
				# Compilation test.
				local check_log=/tmp/dummy.log

				echo 'int main(){}' > dummy.c
				cc dummy.c -v -Wl,--verbose &> "$check_log"
				readelf -l a.out | grep ': /lib'
				# TODO: Check output of the last command.

				local success_count

				success_count=$(grep -c '/usr/lib.*/crt[1in].*succeeded' "$check_log")
				if [ "$success_count" -ne 3 ]
				then
					error "Basic compilation failed!"
					return 1
				fi

				grep -B4 '^ /usr/include' dummy.log

				# TODO: Remove or complete these tests.

				rm -v dummy.c a.out "$check_log"
			fi

			# Move a misplaced file.
			mkdir -pv /usr/share/gdb/auto-load/usr/lib
			mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
		popd
	popd
}

pkg_build_pkg-config() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--with-internal-glib \
			--disable-host-tool \
			--docdir="/usr/share/doc/pkg-config-$version"

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_ncurses() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--mandir=/usr/share/man \
			--with-shared \
			--without-debug \
			--without-normal \
			--enable-pc-files \
			--enable-widec
		make

		make install

		# Redirect non-wide-character ncurses libraries.
		for lib in ncurses form panel menu ; do
			rm -vf						/usr/lib/lib${lib}.so
			echo "INPUT(-l${lib}w)"		>/usr/lib/lib${lib}.so
			ln -sfv ${lib}w.pc			/usr/lib/pkgconfig/${lib}.pc
		done

		# Backward compatibility for -lcurses.
		rm -vf						/usr/lib/libcursesw.so
		echo "INPUT(-lncursesw)"	>/usr/lib/libcursesw.so
		ln -sfv libncurses.so		/usr/lib/libcurses.s

		# Remove a static library that is not handled by configure.
		rm -fv /usr/lib/libncurses++w.a

		# Install the ncurses documentation
		mkdir -v		/usr/share/doc/ncurses-6.2
		cp -v -R doc/*	/usr/share/doc/ncurses-6.2

		# TODO: Add option for non-wide ncurses library
	popd
}

pkg_build_sed() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		# Generate html documentation
		make html

		if [ "$SKIP_TESTS" != true ]
		then
			chown -Rv tester .
			su tester -c "PATH=\"$PATH\" make check"
		fi
	popd
}

pkg_build_psmisc() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		make install
	popd
}

pkg_build_gettext() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--docdir="/usr/share/doc/gettext-$version"

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
		chmod -v 0755 /usr/lib/preloadable_libintl.so
	popd
}

pkg_build_bison() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure --prefix=/usr --docdir="/usr/share/doc/bison-$version"

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_grep() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_bash() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
            --docdir="/usr/share/doc/bash-$version" \
            --without-bash-malloc \
            --with-installed-readline

		make

		# Run tests.
		chown -Rv tester .

		if [ "$SKIP_TESTS" != true ]
		then
			su -s /usr/bin/expect tester <<'EOF'
set timeout -1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EOF
		fi

		make install
	popd
}

pkg_build_libtool() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install

		# Remove a useless static library.
		rm -fv /usr/lib/libltdl.a
	popd
}

pkg_build_gdbm() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--enable-libgdbm-compat

		make

		if [ "$SKIP_TESTS" != true ]
		then
			make -k check || :
		fi

		make install

		# Remove a useless static library.
		rm -fv /usr/lib/libltdl.a
	popd
}

pkg_build_gperf() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure --prefix=/usr "--docdir=/usr/share/doc/gperf-$version"

		make

		[ "$SKIP_TESTS" != true ] && make -j1 check

		make install
	popd
}

pkg_build_expat() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--disable-static \
			--docdir="/usr/share/doc/expat-$version"

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install

		install -v -m644 doc/*.{html,png,css} "/usr/share/doc/expat-$version"
	popd
}

pkg_build_inetutils() # name
{
	local name="$1"

	pushd "$name"
		./configure \
			--prefix=/usr \
            --bindir=/usr/bin \
            --localstatedir=/var \
            --disable-logger \
            --disable-whois \
            --disable-rcp \
            --disable-rexec \
            --disable-rlogin \
            --disable-rsh \
            --disable-servers

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install

		# Move a program to the proper location.
		mv -v /usr/{,s}bin/ifconfig
	popd
}

pkg_build_less() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr --sysconfdir=/etc

		make

		make install
	popd
}

pkg_build_perl() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		patch -Np1 -i "../perl-$version-upstream_fixes-1.patch"

		# Use system libraries.
		export BUILD_ZLIB=False BUILD_BZIP2=0

		sh Configure -des                                         \
			-Dprefix=/usr \
			-Dvendorprefix=/usr \
			-Dprivlib=/usr/lib/perl5/5.34/core_perl \
			-Darchlib=/usr/lib/perl5/5.34/core_perl \
			-Dsitelib=/usr/lib/perl5/5.34/site_perl \
			-Dsitearch=/usr/lib/perl5/5.34/site_perl \
			-Dvendorlib=/usr/lib/perl5/5.34/vendor_perl \
			-Dvendorarch=/usr/lib/perl5/5.34/ \
			-Dman1dir=/usr/share/man/man1 \
			-Dman3dir=/usr/share/man/man3 \
			-Dpager="/usr/bin/less -isR" \
			-Duseshrplib \
			-Dusethreads

		make

		[ "$SKIP_TESTS" != true ] && make test

		make install

		unset BUILD_ZLIB BUILD_BZIP2
	popd
}

pkg_build_XML-Parser() # name
{
	local name="$1"

	pushd "$name"
		perl Makefile.PL

		make

		[ "$SKIP_TESTS" != true ] && make test

		make install
	popd
}

pkg_build_intltool() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		# Fix a warning caused by perl-5.22 and later.
		sed -i 's:\\\${:\\\$\\{:' intltool-update.in

		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
		install -v -Dm644 doc/I18N-HOWTO "/usr/share/doc/intltool-$version/I18N-HOWTO"
	popd
}

pkg_build_autoconf() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_automake() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure --prefix=/usr --docdir="/usr/share/doc/automake-$version"

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_kmod() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--sysconfdir=/etc \
			--with-xz \
			--with-zstd \
			--with-zlib

		make

		make install

		# Create symlinks for backward compatibility with Module-Init-Tools.
		for target in depmod insmod modinfo modprobe rmmod; do
			ln -sfv ../bin/kmod "/usr/sbin/$target"
		done

		ln -sfv kmod /usr/bin/lsmod
	popd
}

pkg_build_libelf() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure --prefix=/usr \
			--disable-debuginfod \
			--enable-libdebuginfod=dummy

		make

		[ "$SKIP_TESTS" != true ] && make check

		# Install only libelf
		make -C libelf install
		install -vm644 config/libelf.pc /usr/lib/pkgconfig
		rm /usr/lib/libelf.a
	popd
}

pkg_build_libffi() # name
{
	local name="$1"

	pushd "$name"
		local optimize="${HOST_OPTIMIZE:-false}"
		local gcc_arch="native"

		[ "$optimize" != "true" ] && gcc_arch="x86_64"

		./configure --prefix=/usr \
            --disable-static \
            --with-gcc-arch="$gcc_arch" \
            --disable-exec-static-tramp

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkh_build_openssl() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./config \
			--prefix=/usr \
			--openssldir=/etc/ssl \
			--libdir=lib \
			shared \
			zlib-dynamic

		make

		if [ "$SKIP_TESTS" != true ]
		then
			# TODO: Filter known failing test
			make test || warning "$name tests were not fully passed!"
		fi

		sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
		make MANSUFFIX=ssl install

		# Add the version to the documentation directory, to be consistent.
		mv -v /usr/share/doc/openssl "/usr/share/doc/openssl-$version"

		# Install additional documentation.
		cp -vfr doc/* "/usr/share/doc/openssl-$version"
	popd
}

pkg_build_Python() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure --prefix=/usr \
			--enable-shared \
			--with-system-expat \
			--with-system-ffi \
			--with-ensurepip=yes \
			--enable-optimizations

		make

		make install

		install -v -dm755 "/usr/share/doc/python-$version/html"

		# Install preformatted documentation
		tar --strip-components=1 \
			--no-same-owner \
			--no-same-permissions \
			-C "/usr/share/doc/python-$version/html" \
			-xvf "../python-$version-docs-html.tar.bz2"
	popd
}

pkg_build_Ninja() # name
{
	local name="$1"

	pushd "$name"
		# Patch to add NINJAOBS variable.
		sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc

		python3 configure.py --bootstrap

		if [ "$SKIP_TESTS" != true ]
		then
			# Run tests.
			./ninja ninja_test
			./ninja_test --gtest_filter=-SubprocessTest.SetWithLots
		fi

		install -vm755 ninja /usr/bin/
		install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
		install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
	popd
}

pkg_build_meson() # name
{
	local name="$1"

	pushd "$name"
		python3 setup.py build

		python3 setup.py install --root=dest
		cp -rv dest/* /
		install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
		install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
	popd
}

pkg_build_coreutils() # name
{
	local name="$1"

	pushd "$name"
		# Patch to fix non-compliances and i18n bugs.
		patch -Np1 -i "../coreutils-$version-i18n-1.patch"

		autoreconf -fiv
		FORCE_UNSAFE_CONFIGURE=1 ./configure \
			--prefix=/usr \
			--enable-no-install-program=kill,uptime

		make

		if [ "$SKIP_TESTS" != true ]
		then
			make NON_ROOT_USERNAME=tester check-root

			# Create a temporary group.
			echo "dummy:x:102:tester" >> /etc/group

			chown -Rv tester .

			su tester -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check"

			# Remove the temporary group.
			sed -i '/dummy/d' /etc/group
		fi

		make install

		# Move programs to locations specified by the FHS.
		mv -v /usr/bin/chroot /usr/sbin
		mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
		sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
	popd
}

pkg_build_check() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure --prefix=/usr --disable-static

		make

		[ "$SKIP_TESTS" != true ] && make check

		make docdir="/usr/share/doc/check-$version" install
	popd
}

pkg_build_diffutils() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_gawk() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		# Ensure that some unneeded files are not installed.
		sed -i 's/extras//' Makefile.in

		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install

		# Install documentation
		mkdir -v "/usr/share/doc/gawk-$version"
		cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} "/usr/share/doc/gawk-$version"
	popd
}

pkg_build_findutils() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr --localstatedir=/var/lib/locate

		make

		if [ "$SKIP_TESTS" != true ]
		then
			# Run tests.
			chown -Rv tester .
			su tester -c "PATH=\"$PATH\" make check"
		fi

		make install
	popd
}

pkg_build_groff() # name
{
	local name="$1"
	local page="${PAGE:-A4}"

	pushd "$name"
		PAGE="$page" ./configure --prefix=/usr

		make -j1

		make install
	popd
}

pkg_build_gzip() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_iproute2() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		# Remove arpd related directories.
		sed -i /ARPD/d Makefile
		rm -fv man/man8/arpd.8

		# Disable modules requiring iptables.
		sed -i 's/.m_ipt.o//' tc/Makefile

		make

		make SBINDIR=/usr/sbin install

		# Install documentation
		mkdir -v				"/usr/share/doc/iproute2-$version"
		cp -v COPYING README*	"/usr/share/doc/iproute2-$version"
	popd
}

pkg_build_kbd() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		# Patch backspace and delete key inconsistencies.
		patch -Np1 -i "../kbd-$version-backspace-1.patch"

		# Disable modules requiring iptables.
		sed -i 's/.m_ipt.o//' tc/Makefile

		# Remove redundant resizecons program,
		sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
		sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in

		./configure --prefix=/usr --disable-vlock

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install

		# Install documentation
		mkdir -v			"/usr/share/doc/kbd-$version"
		cp -R -v docs/doc*	"/usr/share/doc/kbd-$version"
	popd
}

pkg_build_libpipeline() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_make() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_patch() # name
{
	local name="$1"

	pushd "$name"
		./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_tar() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
		make -C doc install-html docdir="/usr/share/doc/tar-$version"
	popd
}

pkg_build_texinfo() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure --prefix=/usr

		sed -e 's/__attribute_nonnull__/__nonnull/' \
   			-i gnulib/lib/malloc/dynarray-skeleton.c

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install

		# Install TeX components
		make TEXMF=/usr/share/texmf install-tex
	popd
}

pkg_build_vim() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		# Change the default vimrc location to /etc.
		echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h

		./configure --prefix=/usr

		make

		if [ "$SKIP_TESTS" != true ]
		then
			# Run tests.
			chown -Rv tester .

			su tester -c "LANG=en_US.UTF-8 make -j1 test" &> /tmp/vim-test.log

			grep --text "ALL DONE" /tmp/vim-test.log

			rm /tmp/vim-test.log
		fi

		make install

		# Create symlinks for vi backward compatibility.
		ln -sv vim /usr/bin/vi
		for L in  /usr/share/man/{,*/}man1/vim.1; do
			ln -sv vim.1 "$(dirname "$L")/vi.1"
		done

		# Create a symlink for consistent documentation.
		ln -sv ../vim/vim82/doc "/usr/share/doc/vim-$version"

		# Configure vim.
		cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1 

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
	popd
}

pkg_build_eudev() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--bindir=/usr/sbin \
			--sysconfdir=/etc \
			--enable-manpages \
			--disable-static

		make

		mkdir -pv /usr/lib/udev/rules.d
		mkdir -pv /etc/udev/rules.d

		[ "$SKIP_TESTS" != true ] && make check

		make install

		# Install some custom rules and support files.
		tar -xvf "../udev-lfs-$version.tar.xz"
		make -f "udev-lfs-$version/Makefile.lfs" install
	popd
}

pkg_build_man-db() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--docdir="/usr/share/doc/man-db-$version" \
			--sysconfdir=/etc \
			--disable-setuid \
			--enable-cache-owner=bin \
			--with-browser=/usr/bin/lynx \
			--with-vgrind=/usr/bin/vgrind \
			--with-grap=/usr/bin/grap \
			--with-systemdtmpfilesdir= \
			--with-systemdsystemunitdir=

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}

pkg_build_procps-ng() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure \
			--prefix=/usr \
			--docdir="/usr/share/doc/procps-ng-$version" \
			--disable-static \
			--disable-kill

		make

		[ "$SKIP_TESTS" != true ] && make check

		make install
	popd
}


pkg_build_util-linux() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		./configure\
			 ADJTIME_PATH=/var/lib/hwclock/adjtime \
			--libdir=/usr/lib \
			--docdir="/usr/share/doc/util-linux-$version" \
			--disable-chfn-chsh \
			--disable-login \
			--disable-nologin \
			--disable-su \
			--disable-setpriv \
			--disable-runuser \
			--disable-pylibmount \
			--disable-static \
			--without-python \
			--without-systemd \
			--without-systemdsystemunitdir \
			runstatedir=/run

		make

		if [ "$SKIP_TESTS" != true ]
		then
			# Remove a test that is hanging when in chroot.
			rm tests/ts/lsns/ioctl_ns

			# Run tests.
			chown -Rv tester .
			su tester -c "make -k check"
		fi

		make install
	popd
}

pkg_build_e2fsprogs() # name
{
	local name="$1"

	pushd "$name"
		mkdir -v build
		pushd build
			../configure \
				--prefix=/usr \
				--sysconfdir=/etc \
				--enable-elf-shlibs \
				--disable-libblkid \
				--disable-libuuid \
				--disable-uuidd \
				--disable-fsck

			make

			[ "$SKIP_TESTS" != true ] && make check

			make install

			#  Remove useless static libraries.
			rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

			# Update info directory.
			gunzip -v /usr/share/info/libext2fs.info.gz
			install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info

			# Create and install documentation.
			makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
			install -v -m644 doc/com_err.info /usr/share/info
			install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
		popd
	popd
}

pkg_build_sysklogd() # name
{
	local name="$1"

	pushd "$name"
		# Fix problems causing a segementation fault.
		sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
		sed -i 's/union wait/int/' syslogd.c

		make

		make BINDIR=/sbin install

		# Configure sysklogd.
		cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF
	popd
}

pkg_build_sysvinit() # name
{
	local name="$1"
	local version="${name##*-}"

	pushd "$name"
		# Patch to remove duplicate programs, and fix a warning.
		patch -Np1 -i "../sysvinit-$version-consolidated-1.patch"

		make

		make install
	popd
}


# FIXME: BLFS UEFI grub
pkg_build_grub() # name
{
	local name="$1"
	local version="${name##*-}"

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
