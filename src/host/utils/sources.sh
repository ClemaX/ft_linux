#!/bin/bash

sources_urls() # url
{
  url="$1"
  wget --timestamping "$url/wget-list"

  sed -e '/.*\/linux-.*\.tar.*/d' wget-list
}

sources_md5() # url
{
  url="$1"
  wget --timestamping "$url/md5sums"

  sed -e '/.*linux-.*\.tar.*/d' md5sums
}

# Fetch a list of urls at "$url/wget-list" and verify file integrity using a
# list of hashes at "$url/md5sums".
sources_fetch() # url dst
{
  url="$1"
  dst="$2"

  cache="/cache"

  mkdir -v "$dst"
  chmod -v a+wt "$dst"

  [ -d "$cache" ] || mkdir -pv "$cache"

  pushd "$cache"
    sources_urls "$url" |  wget --input-file=- --continue --directory-prefix="$cache"

    sources_md5 "$url" | cache_check "rm -rfv"

    while wget --input-file=wget-list --no-clobber --directory-prefix="$cache" \
    | grep 'Downloaded:\s[0-9]* files,\s.*\sin\s.*s\s(.*\s.*/s)'
    do
      cache_check "rm -rfv" < md5sums
    done

    linux_checkout "v4.9.283"
  popd
}
