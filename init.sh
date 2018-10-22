#!/bin/bash

set -e
set -x

APTPROXY=localhost
while getopts ":p:" opt; do
  case $opt in
    p)
      APTPROXY=$OPTARG
      ;;
    \?)
      show_usage
      ;;
  esac
done

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

export DEBIAN_FRONTEND noninteractive
export DEBCONF_NONINTERACTIVE_SEEN true
export LANG C
apt-get update

apt='apt-get -o Dpkg::Options::=--force-confnew -uy'

# Install package for debootstrap
$apt install vim debootstrap tar wget bzip2 screen zerofree apt-cacher-ng lxc parted

# Configure apt proxy
echo ${APTPROXY}
if [ ! -f /etc/apt/apt.conf.d/01proxy ] ; then
  echo Acquire::http::Proxy "http://${APTPROXY}:3142"; \
    >> /etc/apt/apt.conf.d/01proxy
fi

