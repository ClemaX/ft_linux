exec env -i \
    LFS="$LFS" \
    HOME="$HOME" \
    TERM="$TERM" \
    XZ_DEFAULTS="$XZ_DEFAULTS" \
    PS1='\u:\w\$ ' \
    /bin/bash
