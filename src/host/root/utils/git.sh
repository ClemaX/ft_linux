# shellcheck shell=bash

set -e

git_checkout() # repo branch dst
{
    local repo="$1"
    local branch="$2"
    local dst="$3"

	if [ -d "$dst" ]
	then
		if ! [ -d "$dst"/.git ]
		then
			rm -rfv "$dst"
			git_checkout "$repo" "$branch" "$dst"
		else
			pushd "$dst"
				info "Fetching $dst:$branch..."
				git fetch --depth 1 origin "$branch"
			popd
		fi
	else
		info "Cloning $dst:$branch..."
		git clone --depth 1 --single-branch --branch "$branch" "$repo" "$dst"
	fi
}

git_package() # repo_dir [package_name]
{
	local repo_dir="$1"
	local package_name="${2:-$repo_dir}"

	info "Archiving $repo_dir to $package_name.tar..."

	pushd "$repo_dir"
		git archive --prefix="$package_name/" -o "../$package_name.tar" HEAD
	popd
}
