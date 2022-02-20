# Get a list of corrupted files from the hashes given to STDIN.
cache_check() # action [cache]
{
	action="$1"
	cache="${2:-$PWD}"

	info "Checking cache..."

	pushd "$cache"
		md5sum --check --quiet - \
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

# Link all files in cache to dst
cache_link() # dst [cache]
{
	dst="${1}"
	cache="${2:-$PWD}"

	debug "Linking packages from $cache to $dst..."
	cache_list "$cache" | su lfs -c "xargs --no-run-if-empty -I{} ln -s '$cache/{}' '$dst'"
}
