LINUX_REPO="git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"

linux_checkout() # version (example: "v4.9.283")
{
    version="${1:-master}"

    if [ -d linux-stable ]
    then
        if ! [ -d linux-stable/.git ]
        then
            rm -rfv linux-stable
            linux_checkout "$version"
        else
            pushd linux-stable
                git fetch --depth 1 origin "$version"
            popd
        fi
    else
        git clone --depth 1 --single-branch --branch "$version" "$LINUX_REPO" linux-stable
    fi
}
