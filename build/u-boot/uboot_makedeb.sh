#!/bin/bash

set -eux

# u-boot-sunxi Debian version (in stable or testing)
uboot_version="2016.09+dfsg1-2"

build_dir=$PWD

if ! [ -d "${build_dir}/patches/" ]; then
  echo "missing patches/ directory" >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes fakeroot devscripts ncurses-dev u-boot-tools build-essential

tmp_dir=$(mktemp -dp $build_dir uboot_makedeb-tmpXXXXX)
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
increment_opt="-n"

for i in 1 2; do
  mkdir -p "debian/patches/A20-OLinuXino-LIME${i}/"

  while read p; do
    cp "${build_dir}/patches/LIME${i}/${p}" "debian/patches/A20-OLinuXino-LIME${i}/"
    echo "A20-OLinuXino-LIME${i}/${p}" >> debian/patches/series
    patch -p1 "debian/patches/A20-OLinuXino-LIME${i}/${p}"
  
    while read c; do
      dch $increment_opt "u-boot-sunxi > LIME${i}: ${c}"
      increment_opt=
    done < "${build_dir}/patches/LIME${i}/${p}.changelog"
  done < "${build_dir}/patches/LIME${i}/series"
done

export DEB_HOST_ARCH=armhf
time fakeroot debian/rules binary |& tee "${build_dir}/uboot_makedeb.log"

mv ./*sunxi*.deb "${build_dir}/"

cd ~2
rm -rf $tmp_dir

exit 0
