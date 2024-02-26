#! /usr/bin/env bash

### Getting Variables from files
UNY_AUTO_PAT="$(cat UNY_AUTO_PAT)"
export UNY_AUTO_PAT
# shellcheck disable=SC2034
GH_TOKEN="$(cat GH_TOKEN)"
export GH_TOKEN

### Setup Git and GitHub
# Setup Git User -
git config --global user.name "uny-auto"
git config --global user.email "uny-auto@unyqly.com"
git config --global credential.helper store
git config --global advice.detachedHead false

git credential approve <<EOF
protocol=https
url=https://github.com
username=uny-auto
password="$UNY_AUTO_PAT"
EOF

gh -R unypkg/demo2 release create blabla-release --generate-notes \
    /uny/sources/blabla
