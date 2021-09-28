LINUX_REPO="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"

linux_checkout() # version (example: "v4.9.283")
{
    version="${1:-master}"

    if [ -d linux_stable ]
    then
        if ! [ -d linux_stable/.git ]
        then
            rm -rfv linux_stable
            linux_checkout "$version"
        else
            pushd linux_stable
                git fetch --depth 1 origin "$version"
            popd
        fi
    else
        git clone --depth 1 --single-branch --branch "$version" "$LINUX_REPO" linux_stable
    fi
}
