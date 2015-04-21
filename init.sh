#!/bin/bash 

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

# Install and configure apt proxy 
apt-get install apt-cacher-ng 
echo Acquire::http::Proxy "http://localhost:3142"; >> \
 /etc/apt/apt.conf.d/01proxy

# Install packages for kernel and u-boot compilation
apt-get install --force-yes -y gcc-4.7 ncurses-dev uboot-mkimage \
 build-essential vim libusb-1.0-0-dev pkg-config bc netpbm debootstrap dpkg-dev

# Clone repository for image creation 
git clone https://github.com/bleuchtang/sunxi-debian /opt/sunxi-debian
