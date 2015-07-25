#!/bin/bash

set -e
set -x

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script to build LaBriqueInter.net

# OPTIONS

  -k		kernel mode (testing or compil, defautl: compil)

EOF
exit 1
}

KERNEL_MODE="compil"

while getopts ":k:" opt; do
  case $opt in
    k)
      KERNEL_MODE=$OPTARG
      ;;
    \?)
      show_usage
      ;;
  esac
done

cd /opt/sunxi-debian && git pull

if [ $KERNEL_MODE = "compil" ] ; then
  # Remove '-s' option if you want to compile using GIT (for kernel and u-boot)
  /opt/sunxi-debian/olinux/create_sunxi_boot_files.sh -l Labriqueinter.net \
   -t /srv/olinux/sunxi -s | tee /srv/olinux/sunxi.log
  /opt/sunxi-debian/olinux/create_arm_debootstrap.sh -i /srv/olinux/sunxi/ \
   -t /srv/olinux/debootstrap -p -y | tee /srv/olinux/debootstrap.log
  cp /srv/olinux/sunxi.log /srv/olinux/debootstrap.log /srv/olinux/debootstrap/root/
  /opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
   -t /srv/olinux/labriqueinternet_lime1_"$(date '+%d-%m-%Y')".img \
   -b /srv/olinux/debootstrap
  cd /srv/olinux/debootstrap
  rm boot/board.dtb
  ln -s boot/dtb/sun7i-a20-olinuxino-lime2.dtb boot/board.dtb
  /opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
   -t /srv/olinux/labriqueinternet_lime2_"$(date '+%d-%m-%Y')".img \
   -b /srv/olinux/debootstrap
else
  /opt/sunxi-debian/olinux/create_arm_debootstrap.sh -i testing \
   -t /srv/olinux/debootstrap -p -y | tee /srv/olinux/debootstrap.log
  cp /srv/olinux/debootstrap.log /srv/olinux/debootstrap/root/
  # Build olimex lime.img
  /opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
   -t /srv/olinux/labriqueinternet_lime1_"$(date '+%d-%m-%Y')".img \
   -b /srv/olinux/debootstrap \
   -u /srv/olinux/debootstrap/usr/lib/u-boot/A20-OLinuXino-Lime/u-boot-sunxi-with-spl.bin 
  # Build olime lime2 .img
  cd /srv/olinux/debootstrap
  kernel=$(ls -l | grep initrd | cut -d '-' -f3,4,5)
  rm -f boot/dtb boot/dtb-$kernel boot/dtbs/$kernel/*
  cp  usr/lib/linux-image-$kernel/sun7i-a20-olinuxino-lime2.dtb boot/dtbs/$kernel/
  ln -s boot/dtbs/$kernel/sun7i-a20-olinuxino-lime2.dtb boot/dtb
  ln -s boot/dtbs/$kernel/sun7i-a20-olinuxino-lime2.dtb boot/dtb-$kernel
  echo Olimex A20-OLinuXino-LIME2 > etc/flash-kernel/machine
  /opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
   -t /srv/olinux/labriqueinternet_lime2_"$(date '+%d-%m-%Y')".img \
   -b /srv/olinux/debootstrap \
   -u /srv/olinux/debootstrap/usr/lib/u-boot/A20-OLinuXino-Lime2/u-boot-sunxi-with-spl.bin 
fi
