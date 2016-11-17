#!/bin/bash

set -eux

# u-boot-sunxi Debian version (in stable or testing)
uboot_version="2016.09+dfsg1-2"

working_dir=$PWD

# You must be directly in u-boot/
if ! [ -d "${working_dir}/patches/" ]; then
  echo "missing patches/ directory" >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes fakeroot devscripts ncurses-dev build-essential

tmp_dir=$(mktemp -dp $working_dir uboot_makedeb-tmpXXXXX)
pushd $tmp_dir &> /dev/null

if ! grep -q deb-src /etc/apt/sources.list; then
  echo "deb-src http://ftp.fr.debian.org/debian/ stable main" >> /etc/apt/sources.list
  echo "deb-src http://ftp.fr.debian.org/debian/ testing main" >> /etc/apt/sources.list
  apt-get update
fi

apt-get source "u-boot-sunxi=${uboot_version}"

source_dir=$(find -maxdepth 1 -type d -name 'u-boot-*')
pushd $source_dir &> /dev/null

export NAME="La Brique Internet"
export DEBEMAIL="discussions@listes.labriqueinter.net"

debpatches_dir="A20-OLinuXino-labriqueinternet"
mkdir -p "debian/patches/${debpatches_dir}/"

dch -n "Remove all targets, excepting A20-OLinuXino-Lime(2)."

# Applies additional patches on the upstream sources
while read p; do
  cp "${working_dir}/patches/${p}" "debian/patches/${debpatches_dir}/"
  echo "${debpatches_dir}/${p}" >> debian/patches/series
  patch -p1 "debian/patches/${debpatches_dir}/${p}"

  # Completes the deb changelog file with the additional changes
  while read c; do
    dch "u-boot-sunxi/A20-OLinuXino-Lime(2): ${c}"
  done < "${working_dir}/patches/${p}.changelog"
done < "${working_dir}/patches/series"

# Only Sunxi Lime/Lime2 for us
sed '/[[:space:]]\+A20-OLinuXino-Lime.\?[[:space:]]\+/!d' -i debian/targets
export DEB_HOST_ARCH=armhf
time fakeroot debian/rules binary |& tee "${working_dir}/uboot_makedeb.log"

find -maxdepth 1 -name 'u-boot-sunxi*.deb' -exec mv {} "${working_dir}/" \;

cd ~2
rm -rf $tmp_dir

exit 0
