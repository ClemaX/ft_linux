exec env -i \
    LFS="$LFS" \
    HOME="$HOME" \
    TERM="$TERM" \
    LFS_VERSION="$LFS_VERSION" \
    XZ_DEFAULTS="$XZ_DEFAULTS" \
    PS1='\u:\w\$ ' \
    /bin/bash
