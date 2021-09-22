# Turn off bash's hash function
set +h

# Make new files writeable only by owner
umask 022

LC_ALL=POSIX

LFS_TGT="$(uname -m)-lfs-linux-gnu"

# Default path
PATH=/usr/bin

# Add /bin to the path if it isn't a symbolic link
if [ ! -L /bin ]; then
  PATH="/bin:$PATH"
fi

# Add tools to the path with highest priority
PATH="$LFS/tools/bin:$PATH"

CONFIG_SITE="$LFS/usr/share/config.site"

export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
