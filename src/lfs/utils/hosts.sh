# shellcheck shell=bash

LFS_HOSTNAME="${LFS_HOSTNAME:-lfs}"

hosts_init()
{
	# Create the hosts list.
	cat > /etc/hosts << EOF
127.0.0.1                                localhost $LFS_HOSTNAME
::1                                      localhost
EOF
}

hosts_add() # address hostnames
{
	address="$1"; shift
	hostnames="$*"

	printf '%-40s %s\n' "$address" "$hostnames" >> /etc/hosts
}
