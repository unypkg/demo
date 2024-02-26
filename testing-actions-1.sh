#! /usr/bin/env bash

if [[ $EUID -gt 0 ]]; then
    echo "Not root, exiting..."
    exit
fi

apt update && apt install -y gcc g++ gperf bison flex texinfo help2man make libncurses5-dev \
    python3-dev autoconf automake libtool libtool-bin gawk curl bzip2 xz-utils unzip \
    patch libstdc++6 rsync gh git meson ninja-build autopoint

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
# shellcheck disable=SC2034
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

### Setup the Shell
ln -fs /bin/bash /bin/sh

export UNY=/uny

echo "Testing for /usr/bin/env"
type env
ls -lh /usr/bin/env

set -xv

### Add uny user
groupadd uny
useradd -s /bin/bash -g uny -m -k /dev/null uny

### Create uny chroot skeleton
mkdir -pv "$UNY"/home
mkdir -pv "$UNY"/sources/unygit
chmod -v a+wt "$UNY"/sources

mkdir -pv "$UNY"/{etc,var} "$UNY"/usr/{bin,lib,sbin}
mkdir -pv "$UNY"/uny/build/logs

for i in bin lib sbin; do
    ln -sv usr/$i "$UNY"/$i
done

case $(uname -m) in
x86_64) mkdir -pv "$UNY"/lib64 ;;
esac

mkdir -pv "$UNY"/tools

chown -R uny:uny "$UNY"/* #{usr{,/*},lib,var,etc,bin,sbin,tools}
case $(uname -m) in
x86_64) chown -v uny "$UNY"/lib64 ;;
esac

[ ! -e /etc/bash.bashrc ] || mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE

# new vdet date information
uny_build_date_seconds_now="$(date +%s)"
uny_build_date_now="$(date -d @"$uny_build_date_seconds_now" +"%Y-%m-%dT%H.%M.%SZ")"

######################################################################################################################
######################################################################################################################
### functions

function check_for_repo_and_create {
    # Create repo if it doesn't exist
    if [[ $(curl -s -o /dev/null -w "%{http_code}" https://github.com/unypkg/"$pkgname") != "200" ]]; then
        gh repo create unypkg/"$pkgname" --public
        [[ ! -d unygit ]] && mkdir -v unygit
        git -C unygit clone https://github.com/unypkg/"$pkgname".git
        touch unygit/"$pkgname"/emptyfile
        git -C unygit/"$pkgname" add .
        git -C unygit/"$pkgname" commit -m "Make repo non-empty"
        git -C unygit/"$pkgname" push origin
    fi
}

function git_clone_source_repo {
    # shellcheck disable=SC2001
    pkg_head="$(echo "$latest_head" | sed "s|.*refs/[^/]*/||")"
    pkg_git_repo="$(echo "$pkggit" | cut --fields=1 --delimiter=" ")"
    pkg_git_repo_dir="$(basename "$pkg_git_repo" | cut -d. -f1)"
    [[ -d "$pkg_git_repo_dir" ]] && rm -rf "$pkg_git_repo_dir"
    # shellcheck disable=SC2086
    git clone $gitdepth --single-branch -b "$pkg_head" "$pkg_git_repo"
}

function version_details {
    # Download last vdet file
    curl -LO https://github.com/unypkg/"$pkgname"/releases/latest/download/vdet
    old_commit_id="$(sed '2q;d' vdet)"
    uny_build_date_seconds_old="$(sed '4q;d' vdet)"
    [[ $latest_commit_id == "" ]] && latest_commit_id="$latest_ver"

    # pkg will be built, if commit id is different and newer.
    # Before a pkg is built the existence of a vdet-"$pkgname"-new file is checked
    if [[ "$latest_commit_id" != "$old_commit_id" && "$uny_build_date_seconds_now" -gt "$uny_build_date_seconds_old" ]]; then
        {
            echo "$latest_ver"
            echo "$latest_commit_id"
            echo "$uny_build_date_now"
            echo "$uny_build_date_seconds_now"
        } >vdet-"$pkgname"-new
    fi
}

function archiving_source {
    rm -rf "$pkg_git_repo_dir"/.git "$pkg_git_repo_dir"/.git*
    [[ -d "$pkgname-$latest_ver" ]] && rm -rf "$pkgname-$latest_ver"
    mv -v "$pkg_git_repo_dir" "$pkgname-$latest_ver"
    XZ_OPT="--threads=0" tar -cJpf "$pkgname-$latest_ver".tar.xz "$pkgname-$latest_ver"
}

function repo_clone_version_archive {
    check_for_repo_and_create
    git_clone_source_repo
    version_details
    archiving_source
}

######################################################################################################################
######################################################################################################################

######################################################################################################################
### Util-Linux
pkgname="util-linux"
pkggit="https://github.com/util-linux/util-linux.git refs/tags/v[0-9.]*"
gitdepth="--depth=1"

### Get version info from git remote
# shellcheck disable=SC2086
latest_head="$(git ls-remote --refs --tags --sort="v:refname" $pkggit | grep -E "v[0-9]([.0-9]+)+$" | tail -n 1)"
latest_ver="$(echo "$latest_head" | cut --delimiter='/' --fields=3 | sed "s|v||")"
latest_commit_id="$(echo "$latest_head" | cut --fields=1)"

check_for_repo_and_create
git_clone_source_repo

cd "$pkg_git_repo_dir" || exit
./autogen.sh
cd /uny/sources || exit

version_details
archiving_source

gh -R unypkg/demo release create "$pkgname"-"$latest_ver"-"$uny_build_date_now" --generate-notes \
    "$pkgname-$latest_ver".tar.xz

cd "$pkgname-$latest_ver" || exit

./configure ADJTIME_PATH=/var/lib/hwclock/adjtime \
    --libdir=/usr/lib \
    --docdir=/usr/share/doc/util-linux \
    --disable-chfn-chsh \
    --disable-login \
    --disable-nologin \
    --disable-su \
    --disable-setpriv \
    --disable-runuser \
    --disable-pylibmount \
    --disable-static \
    --without-python \
    runstatedir=/run

make -j"$(nproc)"
make install
