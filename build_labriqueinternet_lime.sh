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
 -t /srv/olinux/sunxi -s | tee /srv/olinux/sunxi.log

/opt/sunxi-debian/olinux/create_arm_debootstrap.sh -i /srv/olinux/sunxi/ \
 -t /srv/olinux/debootstrap -p -y | tee /srv/olinux/debootstrap.log

cp /srv/olinux/sunxi.log /srv/olinux/debootstrap.log /srv/olinux/debootstrap/root/

/opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
 -t /srv/olinux/labriqueinternet_lime1_"$(date '+%d-%m-%Y')" -b /srv/olinux/debootstrap

cd /srv/olinux/debootstrap
#search if kernel was build or was installed with debian testing repo
if [ -f boot/board.dtb ] ; then
  # Lime2 archive (change symlink) 
  rm boot/board.dtb
  ln -s boot/dtb/sun7i-a20-olinuxino-lime2.dtb boot/board.dtb
else
  kernel=$(ls -l | grep initrd | cut -d '-' -f3,4,5)
  rm -f boot/dtb boot/dtb-$kernel boot/dtbs/$kernel/*
  cp  usr/lib/linux-image-$kernel/sun7i-a20-olinuxino-lime2.dtb boot/dtbs/$kernel/
  ln -s boot/dtbs/$kernel/sun7i-a20-olinuxino-lime2.dtb boot/dtb
  ln -s boot/dtbs/$kernel/sun7i-a20-olinuxino-lime2.dtb boot/dtb-$kernel
  echo Olimex A20-OLinuXino-LIME2 > etc/flash-kernel/machine
fi

/opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
 -t /srv/olinux/labriqueinternet_lime2_"$(date '+%d-%m-%Y')" -b /srv/olinux/debootstrap

