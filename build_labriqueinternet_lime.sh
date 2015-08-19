#!/bin/bash

set -e
set -x

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

chroot_deb (){
	  LC_ALL=C LANGUAGE=C LANG=C chroot $1 /bin/bash -c "$2"
}

cd /opt/sunxi-debian && git pull

# Build olinux debootstrap with yunohost
/opt/sunxi-debian/olinux/create_arm_debootstrap.sh -i testing \
 -t /srv/olinux/debootstrap -p -y -e | tee /srv/olinux/debootstrap.log
cp /srv/olinux/debootstrap.log /srv/olinux/debootstrap/root/

# Create .img for Lime
/opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
 -t /srv/olinux/labriqueinternet_lime1_cryptedroot_"$(date '+%d-%m-%Y')".img \
 -b /srv/olinux/debootstrap \
 -u /srv/olinux/debootstrap/usr/lib/u-boot/A20-OLinuXino-Lime/u-boot-sunxi-with-spl.bin 

# Create .img for Lime2
echo Olimex A20-OLinuXino-LIME2 > /srv/olinux/debootstrap/etc/flash-kernel/machine
chroot_deb /srv/olinux/debootstrap 'update-initramfs -u -k all'
/opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
 -t /srv/olinux/labriqueinternet_lime2_cryptedroot_"$(date '+%d-%m-%Y')".img \
 -b /srv/olinux/debootstrap \
 -u /srv/olinux/debootstrap/usr/lib/u-boot/A20-OLinuXino-Lime2/u-boot-sunxi-with-spl.bin 

 # Switch to unencrypted root
echo 'LINUX_KERNEL_CMDLINE="console=tty0 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mmcblk0p1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' > $TARGET_DIR/etc/default/flash-kernel
rm /srv/olinux/debootstrap/etc/crypttab
echo '/dev/mmcblk0p1      /	ext4    defaults        0       1' > /srv/olinux/debootstrap/etc/fstab

# Create .img for Lime2 without crypted root
chroot_deb /srv/olinux/debootstrap 'update-initramfs -u -k all'
/opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
 -t /srv/olinux/labriqueinternet_lime2_"$(date '+%d-%m-%Y')".img \
 -b /srv/olinux/debootstrap \
 -u /srv/olinux/debootstrap/usr/lib/u-boot/A20-OLinuXino-Lime2/u-boot-sunxi-with-spl.bin 

# Create .img for Lime without crypted root
echo Olimex A20-OLinuXino-LIME > /srv/olinux/debootstrap/etc/flash-kernel/machine
chroot_deb /srv/olinux/debootstrap 'update-initramfs -u -k all'
/opt/sunxi-debian/olinux/create_device.sh -d img -s 1400 \
 -t /srv/olinux/labriqueinternet_lime1_"$(date '+%d-%m-%Y')".img \
 -b /srv/olinux/debootstrap \
 -u /srv/olinux/debootstrap/usr/lib/u-boot/A20-OLinuXino-Lime/u-boot-sunxi-with-spl.bin 

exit 0
