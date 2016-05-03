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

apt='apt-get -o Dpkg::Options::=--force-confnew --force-yes -uy'

# Install package for debootstrap
$apt install vim debootstrap tar wget bzip2 screen zerofree apt-cacher-ng

# Configure apt proxy
if [ ! -f /etc/apt/apt.conf.d/01proxy ] ; then
  echo 'Acquire::http::Proxy "http://localhost:3142";' >> \
   /etc/apt/apt.conf.d/01proxy
fi

