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

cd  /opt/build.labriqueinter.net/ && git pull

# Build olinux debootstrap with yunohost
./build/create_arm_debootstrap.sh \
 -t /srv/olinux/debootstrap -p -y -e | tee /srv/olinux/debootstrap.log

cp /srv/olinux/debootstrap.log /srv/olinux/debootstrap/root/

boardlist=( 'a20lime2' 'a20lime' )

for BOARD in ${boardlist[@]}; do 

  . ./build/config_board.sh
  echo $FLASH_KERNEL > /srv/olinux/debootstrap/etc/flash-kernel/machine
  chroot_deb /srv/olinux/debootstrap 'update-initramfs -u -k all'
  ./build/create_device.sh -d img -s 1400 \
   -t /srv/olinux/labriqueinternet_${U_BOOT}_uncrypted_"$(date '+%d-%m-%Y')".img \
   -b /srv/olinux/debootstrap \
   -u $BOARD
  
done

 # Switch to unencrypted root
echo 'LINUX_KERNEL_CMDLINE="console=tty0 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mmcblk0p1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' >  /srv/olinux/debootstrap/etc/default/flash-kernel
rm /srv/olinux/debootstrap/etc/crypttab
echo '/dev/mmcblk0p1      /	ext4    defaults        0       1' > /srv/olinux/debootstrap/etc/fstab
  
for BOARD in ${boardlist[@]}; do 

  . ./build/config_board.sh
  echo $FLASH_KERNEL > /srv/olinux/debootstrap/etc/flash-kernel/machine
  chroot_deb /srv/olinux/debootstrap 'update-initramfs -u -k all'
  ./build/create_device.sh -d img -s 1400 \
   -t /srv/olinux/labriqueinternet_${U_BOOT}_"$(date '+%d-%m-%Y')".img \
   -b /srv/olinux/debootstrap \
   -u $BOARD
  
done

exit 0
