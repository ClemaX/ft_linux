disk_mount() # dev mnt
{
  dev="$1"
  mnt="$2"

  [ -d "$mnt" ] || mkdir -pv "$mnt"
  mount -v -t ext4 "${dev}p2" "$mnt"

  [ -d "$mnt/boot" ] || mkdir -v "$mnt/boot"
  mount -v -t ext4 "${dev}p1" "$mnt/boot"
}

disk_umount() # dev
{
  umount -v "${dev}p1"
  umount -v "${dev}p2"
}

disk_partition() # dev
{
  dev="$1"
  # n: do not create default partition table
  fdisk -n "$dev" <<EOF || :
g
n


+200M
n
2


w
EOF
}
