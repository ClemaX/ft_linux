#!/bin/bash

sources_urls() # url
{
  url="$1"
  wget --timestamping "$url/wget-list"

  # TODO: Patch kernel to version 4.x
  cat wget-list
}

sources_md5() # url
{
  url="$1"
  wget --timestamping "$url/md5sums"

  # TODO: Add kernel package hash
  cat md5sums
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
    | grep 'Downloaded: [0-9]* files, .* in .*s (.* .*/s)'
    do
      cache_check "rm -rfv" < md5sums
    done
  popd
}
