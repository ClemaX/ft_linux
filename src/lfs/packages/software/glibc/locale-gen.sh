#!/usr/bin/env bash

LOCALE_GEN_FILE="${1:-/etc/locale.gen}"

while IFS=$'\t ' read -r -a fields
do
    # Skip empty lines and comments starting with a #.
    [[ "${fields[*]}" =~ ^#.*$ || "${fields[*]}" =~ ^$ ]] && continue

    set -- "${fields[@]}"

    input=$1; shift
    charmap=$1; shift
    output=$1; shift
    options=("$@")

    [ "$has_c_utf8" != true ] \
    && [ "$input" = POSIX ] \
    && [ "$charmap" = UTF-8 ] \
    && [ "$output" = C.UTF-8 ] \
    && has_c_utf8=true

    [ "$has_ja_sijs" != true ] \
    && [ "$input" = ja_JP ] \
    && [ "$charmap" = SHIFT_JIS ] \
    && [ "$output" = ja_JP.SIJS ] \
    && has_ja_sijs=true

    cmd=(localedef -i "$input" -f "$charmap" "$output")

    if [ "${options[0]}" = "nofail" ]
    then
        set -- "${options[@]}"
        shift

        "${cmd[@]}" 2>/dev/null || :
    else
        "${cmd[@]}"
    fi
done < "$LOCALE_GEN_FILE"

# Define mandatory locales.
[ "$has_c_utf8" != true ] && localedef -i POSIX -f UTF-8 C.UTF-8 || :
[ "$has_ja_sijs" != true ] && localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS || :