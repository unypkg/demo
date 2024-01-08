#! /usr/bin/env bash

if [[ $EUID -gt 0 ]]; then
    echo "Not root, exiting..."
    exit
fi

apt update && apt install -y gcc g++ gperf bison flex texinfo help2man make libncurses5-dev \
    python3-dev autoconf automake libtool libtool-bin gawk curl bzip2 xz-utils unzip \
    patch libstdc++6 rsync gh git meson ninja-build

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

### Add uny user
groupadd uny
useradd -s /bin/bash -g uny -m -k /dev/null uny

sudo -i -u uny bash <<"EOFUNY"
set -vx

cat >~/.bash_profile <<"EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
set +h
umask 022
UNY=/uny
LC_ALL=POSIX
UNY_TGT=$(uname -m)-uny-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$UNY/tools/bin:$PATH
CONFIG_SITE=$UNY/usr/share/config.site
export UNY LC_ALL UNY_TGT PATH CONFIG_SITE
MAKEFLAGS="-j$(nproc)"
EOF
EOFUNY

sudo -i -u uny bash <<"EOFUNY"
set -vx

echo $HOME
echo $TERM
echo $PS1
echo $UNY
echo $MAKEFLAGS
EOFUNY
