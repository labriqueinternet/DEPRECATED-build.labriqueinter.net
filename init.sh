#!/bin/sh

set -e
set -x

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

export DEBIAN_FRONTEND noninteractive
export DEBCONF_NONINTERACTIVE_SEEN true
export LANG C
apt-get update

apt='apt-get -o Dpkg::Options::=--force-confnew --force-yes -uy'

# Install and configure apt proxy
if [ ! -f /etc/apt/apt.conf.d/01proxy ] ; then
  $apt install apt-cacher-ng
  echo Acquire::http::Proxy "http://localhost:3142"; >> \
   /etc/apt/apt.conf.d/01proxy
fi

# Install packages for kernel and u-boot compilation
$apt install gcc-4.7 ncurses-dev uboot-mkimage \
 build-essential vim libusb-1.0-0-dev pkg-config bc netpbm debootstrap dpkg-dev

# Clone repository for image creation
git clone https://github.com/bleuchtang/sunxi-debian /opt/sunxi-debian
