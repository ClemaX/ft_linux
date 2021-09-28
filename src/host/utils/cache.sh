# Get a list of corrupted files from the hashes given to STDIN.
cache_check() # action [cache]
{
  action="$1"
  cache="${2:-$PWD}"

  echo "Checking cache..."

  pushd "$cache"
    md5sum --check --quiet --ignore-missing - \
    | grep FAILED \
    | sed 's/\(.*\):.*/\1/' \
    | xargs --no-run-if-empty $action
  popd
}

cache_list() # [cache]
{
  cache="${1:-PWD}"

  cut -b 35- < "$cache/md5sums" && echo linux-stable
}

# Link all files in cache to
cache_link() # dst [cache]
{
  dst="${1}"
  cache="${2:-$PWD}"

  cache_list "$cache" | xargs --no-run-if-empty -I{} ln -sv "$cache/{}" "$dst"
}
