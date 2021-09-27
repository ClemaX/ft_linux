# Get a list of corrupted files
cache_check() # action [cache]
{
  action="$1"
  cache="$2"

  md5sum --check --quiet --ignore-missing "$cache" \
  | grep FAILED \
  | sed 's/\(.*\):.*/\1/' \
  | xargs --no-run-if-empty $action
}

cache_list() # [cache]
{
  cache="${1:PWD}"

  sources_md5 | cut -b 35- && echo linux-stable
}

# Link all files in cache to
cache_link() # dst [cache]
{
  dst="${1}"
  cache="${2:PWD}/"

  cache_list "$cache" | xargs --no-run-if-empty -I{} ln -s {} "$dst"
}
