# Get a list of corrupted files from the hashes given to STDIN.
cache_check() # action [cache]
{
	local action="$1"
	local cache="${2:-$PWD}"

	info "Checking cache..."

	pushd "$cache"
		md5sum --check --quiet - \
		| grep FAILED \
		| sed 's/\(.*\):.*/\1/' \
		| xargs --no-run-if-empty $action
	popd
}

# Print existing cached files from an url-list given to STDIN.
cache_list() # [cache]
{
	local cache="${1:-$PWD}"

	local src

	pushd "$cache"
		while IFS= read -r src
		do
			src=$(basename "$src")
			[ -f "$src" ] && echo "$src"
		done
	popd
}

# Link all files from an url-list exisiting in cache to dst.
cache_link() # dst [cache] [user]
{
	local dst="${1}"
	local cache="${2:-$PWD}"
	local user="${3:-root}"

	cache_list "$cache" | su "$user" -c "xargs --no-run-if-empty -I{} ln -s '$cache/{}' '$dst'"
}
