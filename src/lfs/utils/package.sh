NCORES=$(nproc)
export MAKEFLAGS="-j${NCORES:-1}"
export NINJAJOBS="${NCORES:-1}"

# Build a compressed package.
pkg_extract() # pkg builder
{
	local pkg="$1"
	local builder="$2"

	local base="${pkg##*/}"
	local name=$(tar -tf "$pkg" | head -n1)
	name="${name%%/*}"

	local logfile=$(mktemp "$name.XXXX.log")

	info "Extracting $base to $name..."
	tar --no-same-owner --skip-old-files -xf "$pkg"

	info "Building $name..."
	if "$builder" "$name" >"$logfile" 2>&1
	then
		rm "$logfile"
	else
		error "Could not build $name! Build log is located at $logfile."
		ERROR_LOG="$logfile"
		false
	fi
}
