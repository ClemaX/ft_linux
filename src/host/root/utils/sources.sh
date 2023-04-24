# shellcheck shell=bash

set -e

MAX_REDIR=80

# Fetch and filter source urls.
sources_urls() # [url]
{
	local url="${1:-}"

	[ -z "$url" ] || wget --timestamping "$url/wget-list"

	sed -e '/\/linux\-[^\/]*.tar[^\/]*/d' wget-list
}

# Fetch and filter md5 hashes.
sources_md5() # [url]
{
	local url="${1:-}"

	[ -z "$url" ] || wget --timestamping "$url/md5sums"

	sed -e '/.*[[:space:]]linux-[^\/]*\.tar[^\/]*/d' md5sums
}

# Fetch multiple files in parallel.
parallel_fetch() # options [input] [dst] [count]
{
	local options
	local input="${2:-}"
	local dst="${3:-$PWD}"
	local count="${4:-4}"
	local wget_cmd

	read -r -a options <<< "$1"

	wget_cmd=(
		wget "${options[@]}"
			--input-file=-
			--max-redirect="${MAX_REDIR}"
			--directory-prefix="$dst"
			--no-verbose
	)

	if [ -z "$input" ]
	then
		parallel -j"$count" --round-robin --bar "${wget_cmd[@]}"
	else
		parallel -a "$input" -j"$count" --pipepart --round-robin --bar "${wget_cmd[@]}"
	fi
}

# Fetch an archive at "proto://repo:branch" and create a tar archive and a
# md5 hash.
sources_fetch_git() # proto://repo:branch dst [user]
{
	local dst="$2"
	local user="${3:-root}"

	if [[ "$1" =~ ^([^:]+)://([^:]+):(.*) ]]
	then
		local proto="${BASH_REMATCH[1]}"
		local repo="${BASH_REMATCH[2]}"
		local branch="${BASH_REMATCH[3]}"

		local name package_name

		name="$(basename "$repo" .git)"
		package_name="$name-$branch"

		if ! md5sum --check --quiet "$package_name.md5"
		then
			if ! [ "$proto" = "git" ] \
			|| ! git archive --remote "$proto://$repo" "$branch" -o "$package_name.tar"
			then
				git_checkout "$proto://$repo" "$branch" "$name"
				git_package "$name" "$package_name"
			fi

			md5sum "$package_name.tar" > "$package_name.md5"
		fi

		info "Linking $PWD/$package_name to $dst..."
		su "$user" -c "ln -vsf '$PWD/$package_name.tar' '$dst'"
	else
		error "Invalid url format: $1" && false
	fi
}

# Fetch sources given an url-list at "name.lst" and verify their integrity using
# md5 hashes at "name.md5".
sources_fetch_list() # name dst [cache] [user]
{
	local dst="$2"
	local cache="${3:-/cache}"
	local user="${4:-root}"

	local srcs_name base

	srcs_name=$(realpath "$1")
	base=$(basename "$srcs_name")

	local proto repo
	local name package_name

	pushd "$cache"
		[ -f "$base.urls" ] && rm -fv "$base.urls"

		while IFS= read -r url
		do
			# Fetch git repo or store url.
			if [[ "$url" =~ ^[^:]+://[^:]+\.git:.* ]]
			then
				sources_fetch_git "$url" "$dst" "$user"
			else
				echo "$url" >> "$base.urls"
			fi
		done < "$srcs_name.lst"

		if [ -f "$base.urls" ]
		then
			# Check for cache integrity.
			until cache_complete "$cache" < "$srcs_name.md5"
			do
				# Resume partial downloads.
				parallel_fetch "--continue" < "$base.urls" \
				|| warning "Warning: $? jobs failed!"

				# Delete corrupted files.
				cache_check "rm -rfv" "$cache" < "$srcs_name.md5"

				# Download missing files.
				parallel_fetch --no-clobber < "$base.urls"
			done

			# Download missing files.
			#while parallel_fetch --no-clobber < "$base.urls" \
			#| grep 'Downloaded:\s[0-9]* files,\s.*\sin\s.*s\s(.*\s.*/s)'
			#do
			#	cache_check "rm -rfv" "$cache" < "$srcs_name.md5"
			#done

			# Link to destination.
			info "All '$base' packages have been downloaded! Linking to '$dst'..."
			cache_link "$dst" "$cache" "$user" < "$base.urls"
		fi
	popd
}

# Fetch a list of urls at "$url/wget-list" and verify file integrity using a
# list of hashes at "$url/md5sums".
sources_fetch() # url dst [cache] [user]
{
	local url="$1"
	local dst="$2"
	local cache="${3:-/cache}"
	local user="${4:-root}"

	[ -d "$dst" ] || mkdir -v "$dst" && chmod -v a+wt "$dst"

	[ -d "$cache" ] || mkdir -pv "$cache" #&& [ -z $user ] || chown cache ":$user"

	pushd "$cache"
		# Fetch lists.
		sources_urls "$url" > lfs.lst
		sources_md5 "$url" > lfs.md5

		# Fetch LFS sources.
		sources_fetch_list lfs "$dst" "$cache" "$user"

		# Fetch beyond LFS sources.
		sources_fetch_list "$HOME/sources/blfs" "$dst" "$cache" "$user"

		# Fetch Linux kernel.
		sources_fetch_git "$KERNEL_SOURCE" "$dst" "$user"
	popd
}
