MAX_REDIR=80

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

parallel_fetch() # options [file] [dst] [count]
{
  options="$1"
  input="${2:-}"
  dst="${3:-$PWD}"
  count="${4:-4}"

  if [ -z $input ]
  then
    parallel -j"$count" --round-robin --bar wget --input-file=- $options --quiet --max-redirect="${MAX_REDIR}" --directory-prefix="$dst"
  else
    parallel -a "$input" -j"$count" --pipepart --round-robin --bar wget --input-file=- $options --quiet --max-redirect="${MAX_REDIR}" --directory-prefix="$dst"
  fi
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

    # Check for cache integrity
    if ! [ sources_md5 "$url" | cache_check "false" ]
    then
      # Resume partial downloads.
      sources_urls "$url" | parallel_fetch "--continue --quiet" || echo "Warning: $? jobs failed!"

      # Delete corrupted files.
      sources_md5 "$url" | cache_check "rm -rfv"

      # Download the deleted files again.
      # TODO: Add a max retry mechanism
      # TODO: Add pipepart flag
      while parallel_fetch --no-clobber wget-list \
      | grep 'Downloaded:\s[0-9]* files,\s.*\sin\s.*s\s(.*\s.*/s)'
      do
        cache_check "rm -rfv" < md5sums
      done
    fi

    echo 'All packages have been downloaded!'

    # Checkout the linux kernel sources
    linux_checkout "$LINUX_VERSION"
  popd
}
