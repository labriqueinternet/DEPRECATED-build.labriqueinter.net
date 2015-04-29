#!/bin/bash

set -e
set -x

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

cd /opt/sunxi-debian && git pull

# Remove '-s' option if you want to compile using GIT (for kernel and u-boot)
/opt/sunxi-debian/olinux/create_sunxi_boot_files.sh -l Labriqueinter.net \
 -t /srv/olinux/sunxi -s

/opt/sunxi-debian/olinux/create_arm_debootstrap.sh -i /srv/olinux/sunxi/ \
 -t /srv/olinux/debootstrap -p -y

# partitioning doesn't work with losetup on my board...
#/opt/sunxi-debian/olinux/create_device.sh -d img -s 1200 \
# -t /srv/olinux/yunohost_lime.img -b /srv/olinux/debootstrap

tar --same-owner --preserve-permissions -cvf \
 /srv/olinux/labriqueinternet_$(date "+%d-%m-%Y").tar \
 -C /srv/olinux/debootstrap .
