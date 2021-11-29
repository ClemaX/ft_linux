fs_hierarchy()
{
	# Create required root subdirectories.
	mkdir -pv /{boot,home,mnt,opt,srv}

	# Create required subdirectory hierarchies.
	mkdir -pv /etc/{opt,sysconfig}
	mkdir -pv /lib/firmware
	mkdir -pv /media/{floppy,cdrom}
	mkdir -pv /usr/{,local/}{include,src}
	mkdir -pv /usr/local/{bin,lib,sbin}
	mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
	mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
	mkdir -pv /usr/{,local/}share/man/man{1..8}
	mkdir -pv /var/{cache,local,log,mail,opt,spool}
	mkdir -pv /var/lib/{color,misc,locate}

	ln -sfv /run /var/run
	ln -sfv /run/lock /var/lock

	# Restrict root home directory permissions.
	install -dv -m 0750 /root
	# Make /tmp available to anyone.
	install -dv -m 1777 /tmp /var/tmp
}
