group_init()
{
	debug "Initializing /etc/group..."
	# Create the group list.
	cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF
}

group_add() # group gid
{
	local group="$1"
	local gid="$2"

	debug "Adding group $group with gid $gid..."

	if cut -d':' -f1 /etc/group | grep -m1 "^$group\$"
	then
		error "${FUNCNAME[0]}: The group '$group' already exists!"
		return 1
	fi

	if cut -d':' -f3 /etc/group | grep -m1 "^$gid\$"
	then
		error "${FUNCNAME[0]}: A group with id '$gid' already exists!"
		return 1
	fi

	echo "$group:x:$gid:" >> /etc/group
}

user_init()
{
	group_init

	debug "Initializing /etc/passwd..."
	# Create the user list.
	cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF
}

user_add() # user uid [shell] [desc]
{
	local user="$1"
	local uid="$2"
	local shell="${3:-/bin/bash}"
	local desc="${4:-}"

	local group="$user"
	local gid="$uid"

	local home="/home/$user"

	debug "Adding user $user with uid $uid, $home and $shell..."

	# Check if the user already exists.
	if cut -d':' -f1 /etc/passwd | grep -m1 "^$user\$"
	then
		error "${FUNCNAME[0]}: The user '$user' already exists!"
		return 1
	fi

	# Add the user's group.
	if group_add "$group" "$gid"
	then
		# Add the user to the user list.
		echo "$user:x:$uid:$gid:$desc:$home:$shell" >> /etc/passwd

		# Create the user's home directory.
		install -o "$user" -d "$home"
	fi
}
