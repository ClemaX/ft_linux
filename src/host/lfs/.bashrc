# Turn off bash's hash function.
set +h

# Make new files writeable only by owner.
umask 022

# Use the compatiblity locale.
LC_ALL=POSIX

# Set the LFS's name according to architecture.
LFS_TGT="$(uname -m)-lfs-linux-gnu"

# Default executable path
PATH=/usr/bin

# Add /bin to the path if it isn't a symbolic link.
if [ ! -L /bin ]
then
	PATH="/bin:$PATH"
fi

# Add tools to the path with highest priority.
PATH="$LFS/tools/bin:$PATH"

# Use the LFS's config site instead of the host's.
CONFIG_SITE="$LFS/usr/share/config.site"

export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
