MAX_REDIR=80

sources_urls() # url
{
  url="$1"

  [ -z "$url" ] || wget --timestamping "$url/wget-list"

  sed -e '/.*\/linux-.*\.tar.*/d' wget-list
}

sources_md5() # [url]
{
  url="${1:-}"

  [ -z "$url" ] || wget --timestamping "$url/md5sums"

  sed -e '/.*linux-.*\.tar.*/d' md5sums
}

parallel_fetch() # options [input] [dst] [count]
{
  options="$1"
  input="${2:-}"
  dst="${3:-$PWD}"
  count="${4:-4}"

  if [ -z "$input" ]
  then
    parallel -j"$count" --round-robin --bar wget --input-file=- $options --quiet --max-redirect="${MAX_REDIR}" --directory-prefix="$dst"
  else
    parallel -a "$input" -j"$count" --pipepart --round-robin --bar wget --input-file=- $options --quiet --max-redirect="${MAX_REDIR}" --directory-prefix="$dst"
  fi
}

# Fetch a list of urls at "$url/wget-list" and verify file integrity using a
# list of hashes at "$url/md5sums".
sources_fetch() # url dst [user]
{
  url="$1"
  dst="$2"
  #user="$3"

  cache="/cache"

  [ -d "$dst" ] || mkdir -v "$dst" && chmod -v a+wt "$dst"

  [ -d "$cache" ] || mkdir -pv "$cache" #&& [ -z $user ] || chown cache ":$user"

  pushd "$cache"

    # Check for cache integrity.
    if ! sources_md5 "$url" | cache_check "false"
    then
      # Resume partial downloads.
      sources_urls "$url" | parallel_fetch "--continue --quiet" || warning "Warning: $? jobs failed!"

      # Delete corrupted files.
      cache_check "rm -rfv" < md5sums
    fi
    # Download missing files.
    # TODO: Add a max retry mechanism
    # TODO: Add pipepart flag
    while sources_urls "$url" | parallel_fetch --no-clobber \
    | grep 'Downloaded:\s[0-9]* files,\s.*\sin\s.*s\s(.*\s.*/s)'
    do
      cache_check "rm -rfv" < md5sums
    done

    info "All packages have been downloaded! Linking to '$dst'..."
    cache_link "$dst"

    # Checkout the linux kernel sources.
    linux_checkout "$LINUX_VERSION"
  popd
}
