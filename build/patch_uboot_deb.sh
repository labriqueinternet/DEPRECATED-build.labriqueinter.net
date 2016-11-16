#!/bin/bash

set -eux

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes fakeroot devscripts ncurses-dev uboot-mkimage build-essential

tmp_dir=$(mktemp -dp /opt/build.labriqueinter.net/ uboot-makedeb-tmpXXXXX)
pushd $tmp_dir &> /dev/null

if ! grep -q deb-src /etc/apt/sources.list; then
  echo 'deb-src http://ftp.fr.debian.org/debian/ stable main contrib' >> /etc/apt/sources.list
  apt-get update
fi

apt-get source u-boot-sunxi/stable
uboot_dir=$(find -maxdepth 1 -type d -name 'u-boot-*')
pushd $uboot_dir &> /dev/null

wget -P debian/patches/A20-OLinuXino-LIME2/\
  https://raw.githubusercontent.com/OLIMEX/OLINUXINO/master/SOFTWARE/A20/A20-build-3.4.103-release-4/a20-phy-dram.patch
echo A20-OLinuXino-LIME2/a20-phy-dram.patch >> debian/patches/series

export DEB_HOST_ARCH=armhf
export DEBIAN_REVISION="$(dpkg-parsechangelog --show-field Version | sed -e 's,.*+dfsg,+dfsg,')-labriqueinternet1"

fakeroot debian/rules binary

cd ~2
rm -rf $tmp_dir

exit 0
