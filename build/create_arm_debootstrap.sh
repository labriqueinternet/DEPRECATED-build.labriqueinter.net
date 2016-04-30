#!/bin/bash

######################
#    Debootstrap     #
######################

set -e
set -x

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script to create a minimal deboostrap

# OPTIONS

  -b		olinux board (see config_board.sh) 	(default: a20lime)
  -a		add packages to deboostrap
  -n		hostname				(default: olinux)
  -t		target directory for debootstrap	(default: ./tmp/debootstrap)
  -y		install yunohost (doesn't work with cross debootstrap)
  -r		debian release				(default: jessie)
  -d		yunohost distribution			(default: stable)
  -c		cross debootstrap
  -p		use and set aptcacher proxy
  -e		configure for encrypted partition	(default: false)

EOF
exit 1
}

DEBIAN_RELEASE=jessie
TARGET_DIR=./tmp/debootstrap
DEB_HOSTNAME=olinux
REP=$(dirname $0)
APT='DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes'
INSTALL_YUNOHOST_DIST='stable'

<<<<<<< 35b24b2f2d1831e706541bdadc15444746a4a61f
while getopts ":a:b:n:t:d:r:ycp:e" opt; do
=======
while getopts ":a:b:n:t:d:ycp:e" opt; do
>>>>>>> add distrib for yunohost installation
  case $opt in
    b)
      BOARD=$OPTARG
      ;;
    a)
      PACKAGES=$OPTARG
      ;;
    n)
      DEB_HOSTNAME=$OPTARG
      ;;
    t)
      TARGET_DIR=$OPTARG
      ;;
    y)
      INSTALL_YUNOHOST=yes
      ;;
    d)
      INSTALL_YUNOHOST_DIST=$OPTARG
      ;;
<<<<<<< 35b24b2f2d1831e706541bdadc15444746a4a61f
    r)
      DEBIAN_RELEASE=$OPTARG
      ;;
=======
>>>>>>> add distrib for yunohost installation
    c)
      CROSS=yes
      ;;
    p)
      APTCACHER=$OPTARG
      ;;
    e)
      ENCRYPT=yes
      ;;
    \?)
      show_usage
      ;;
  esac
done

. ${REP}/config_board.sh

rm -rf $TARGET_DIR && mkdir -p $TARGET_DIR

chroot_deb (){
  LC_ALL=C LANGUAGE=C LANG=C chroot $1 /bin/bash -c "$2"
}


mount_dir (){
  mount --bind /proc $1/proc
  mount --bind /sys $1/sys
  mount --bind /dev $1/dev
  mount --bind /dev/pts $1/dev/pts
}

umount_dir (){
  # Umount proc, sys, and dev
  umount -l "$1"/proc
  umount -l "$1"/sys
  umount -l "$1"/dev/pts
  umount -l "$1"/dev
}

finish(){
  umount_dir $TARGET_DIR 
}
trap finish EXIT

# Debootstrap
if [ ${CROSS} ] ; then
  if ! mount | grep -q binfmt_misc ; then
    mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
    bash ${REP}/script/binfmt-misc-arm.sh unregister
    bash ${REP}/script/binfmt-misc-arm.sh
  fi
  if [ ${APTCACHER} ] ; then
    debootstrap --arch=armhf --foreign $DEBIAN_RELEASE $TARGET_DIR http://${APTCACHER}:3142/ftp.fr.debian.org/debian/
  else
    debootstrap --arch=armhf --foreign $DEBIAN_RELEASE $TARGET_DIR
  fi
  cp /usr/bin/qemu-arm-static $TARGET_DIR/usr/bin/
  cp /etc/resolv.conf $TARGET_DIR/etc
  chroot_deb $TARGET_DIR '/debootstrap/debootstrap --second-stage'
elif [ ${APTCACHER} ] ; then
 debootstrap $DEBIAN_RELEASE $TARGET_DIR http://${APTCACHER}:3142/ftp.fr.debian.org/debian/
else
 debootstrap $DEBIAN_RELEASE $TARGET_DIR
fi

# mount proc, sys and dev
mount_dir $TARGET_DIR

# Configure debian apt repository
cat <<EOT > $TARGET_DIR/etc/apt/sources.list
deb http://ftp.fr.debian.org/debian $DEBIAN_RELEASE main contrib non-free
deb http://security.debian.org/ $DEBIAN_RELEASE/updates main contrib non-free
EOT
cat <<EOT > $TARGET_DIR/etc/apt/apt.conf.d/71-no-recommends
APT::Install-Suggests "0";
EOT

if [ ${APTCACHER} ] ; then
 cat <<EOT > $TARGET_DIR/etc/apt/apt.conf.d/01proxy
Acquire::http::Proxy "http://${APTCACHER}:3142";
EOT
 # if we are in docker and chroot and we want to have proxy resolvedi
 cp $TARGET_DIR/etc/hosts $TARGET_DIR/tmp
 cp /etc/hosts $TARGET_DIR/etc/
fi

chroot_deb $TARGET_DIR 'apt-get update'

# Add HyperCube packages
PACKAGES="jq udisks-glue php5-fpm ntfs-3g $PACKAGES"

# Add useful packages
chroot_deb $TARGET_DIR "$APT openssh-server ntp parted locales vim-nox bash-completion rng-tools $PACKAGES"
echo 'HRNGDEVICE=/dev/urandom' >> $TARGET_DIR/etc/default/rng-tools
echo '. /etc/bash_completion' >> $TARGET_DIR/root/.bashrc

# Use dhcp on boot
cat <<EOT > $TARGET_DIR/etc/network/interfaces
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
  post-up ip a a fe80::42:babe/128 dev eth0

allow-hotplug usb0
iface usb0 inet dhcp
EOT

# Debootstrap optimisations from igorpecovnik
# change default I/O scheduler, noop for flash media, deadline for SSD, cfq for mechanical drive
cat <<EOT >> $TARGET_DIR/etc/sysfs.conf
block/mmcblk0/queue/scheduler = noop
#block/sda/queue/scheduler = cfq
EOT

# flash media tunning
if [ -f "$TARGET_DIR/etc/default/tmpfs" ]; then
  sed -e 's/#RAMTMP=no/RAMTMP=yes/g' -i $TARGET_DIR/etc/default/tmpfs
  sed -e 's/#RUN_SIZE=10%/RUN_SIZE=128M/g' -i $TARGET_DIR/etc/default/tmpfs
  sed -e 's/#LOCK_SIZE=/LOCK_SIZE=/g' -i $TARGET_DIR/etc/default/tmpfs
  sed -e 's/#SHM_SIZE=/SHM_SIZE=128M/g' -i $TARGET_DIR/etc/default/tmpfs
  sed -e 's/#TMP_SIZE=/TMP_SIZE=1G/g' -i $TARGET_DIR/etc/default/tmpfs
fi

# Generate locales
sed -i "s/^# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/" $TARGET_DIR/etc/locale.gen
sed -i "s/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" $TARGET_DIR/etc/locale.gen
chroot_deb $TARGET_DIR "locale-gen en_US.UTF-8"

# Update timezone
echo 'Europe/Paris' > $TARGET_DIR/etc/timezone
chroot_deb $TARGET_DIR "dpkg-reconfigure -f noninteractive tzdata"

# Add fstab for root
chroot_deb $TARGET_DIR "echo '/dev/mmcblk0p1 / ext4	defaults	0	1' >> /etc/fstab"
# Configure tty
cat <<EOT > $TARGET_DIR/etc/init/ttyS0.conf
start on stopped rc RUNLEVEL=[2345]
stop on runlevel [!2345]

respawn
exec /sbin/getty --noclear 115200 ttyS0
EOT
chroot_deb $TARGET_DIR 'cp /lib/systemd/system/serial-getty@.service /etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service'
chroot_deb $TARGET_DIR 'sed -e s/"--keep-baud 115200,38400,9600"/"-L 115200"/g -i /etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service'
chroot_deb $TARGET_DIR "sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config"

# Good right on some directories
chroot_deb $TARGET_DIR 'chmod 1777 /tmp/'
chroot_deb $TARGET_DIR 'chgrp mail /var/mail/'
chroot_deb $TARGET_DIR 'chmod g+w /var/mail/'
chroot_deb $TARGET_DIR 'chmod g+s /var/mail/'

# Set hostname
echo $DEB_HOSTNAME > $TARGET_DIR/etc/hostname
sed -i "1i127.0.1.1\t${DEB_HOSTNAME}" $TARGET_DIR/etc/hosts

# Add firstrun and secondrun init script
install -m 755 -o root -g root ${REP}/script/firstrun $TARGET_DIR/usr/local/bin/
install -m 755 -o root -g root ${REP}/script/secondrun $TARGET_DIR/usr/local/bin/
install -m 755 -o root -g root ${REP}/script/hypercube/hypercube.sh $TARGET_DIR/usr/local/bin/
install -m 444 -o root -g root ${REP}/script/firstrun.service $TARGET_DIR/etc/systemd/system/
install -m 444 -o root -g root ${REP}/script/secondrun.service $TARGET_DIR/etc/systemd/system/
install -m 444 -o root -g root ${REP}/script/hypercube/hypercube.service $TARGET_DIR/etc/systemd/system/
chroot_deb $TARGET_DIR "/bin/systemctl daemon-reload >> /dev/null"
chroot_deb $TARGET_DIR "/bin/systemctl enable firstrun >> /dev/null"
chroot_deb $TARGET_DIR "/bin/systemctl enable hypercube >> /dev/null"

# Add hypercube scripts
mkdir $TARGET_DIR/var/log/hypercube
install -m 444 -o root -g root ${REP}/script/hypercube/install.html $TARGET_DIR/var/log/hypercube/

if [ $INSTALL_YUNOHOST ] ; then
  chroot_deb $TARGET_DIR "mkdir -p /run/systemd/system/"

  chroot_deb $TARGET_DIR "$APT git"
  chroot_deb $TARGET_DIR "git clone https://github.com/YunoHost/install_script /tmp/install_script"
  chroot_deb $TARGET_DIR "cd /tmp/install_script && ./install_yunohost -a -d ${INSTALL_YUNOHOST_DIST}"
fi

echo 'deb http://ftp.fr.debian.org/debian jessie-backports main' > $TARGET_DIR/etc/apt/sources.list.d/backports.list
# Install linux-image, u-boot and flash-kernel from backports
cat <<EOT > ${TARGET_DIR}/etc/apt/preferences.d/kernel-backports
Package: linux-image*
Pin: release a=jessie-backports
Pin-Priority: 990

Package: u-boot*
Pin: release a=jessie-backports
Pin-Priority: 990
>>>>>>> Rename install_yunohost script to follow upstream changes.

  chroot_deb $TARGET_DIR "rmdir /run/systemd/system/ /run/systemd/ 2> /dev/null || true"
fi

#echo 'deb http://ftp.fr.debian.org/debian jessie-backports main' > $TARGET_DIR/etc/apt/sources.list.d/backports.list
## Install linux-image, u-boot and flash-kernel from backports
#cat <<EOT > ${TARGET_DIR}/etc/apt/preferences.d/kernel-backports
#Package: linux-image*
#Pin: release a=jessie-backports
#Pin-Priority: 990
#
#Package: u-boot*
#Pin: release a=jessie-backports
#Pin-Priority: 990
#
#Package: flash-kernel*
#Pin: release a=jessie-backports
#Pin-Priority: 990
#
#Package: *
#Pin: release a=jessie-backports
#Pin-Priority: 50
#EOT

umount_dir $TARGET_DIR
chroot_deb $TARGET_DIR 'apt-get update'
chroot_deb $TARGET_DIR 'apt-get upgrade -y --force-yes'

if [ $ENCRYPT ] ; then
  PACKAGES="stunnel dropbear busybox cryptsetup"
  echo 'LINUX_KERNEL_CMDLINE="console=ttyS1 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mapper/root cryptopts=target=root,source=/dev/mmcblk0p2,cipher=aes-xts-plain64,size=256,hash=sha1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' > $TARGET_DIR/etc/default/flash-kernel
else
  echo 'LINUX_KERNEL_CMDLINE="console=ttyS1 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mmcblk0p1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' > $TARGET_DIR/etc/default/flash-kernel
fi

mkdir $TARGET_DIR/etc/flash-kernel
echo $FLASH_KERNEL > $TARGET_DIR/etc/flash-kernel/machine
# Force kernel version (temporary bug with kernel 4.5)
chroot_deb $TARGET_DIR "DEBIAN_FRONTEND=noninteractive $APT linux-image-armmp flash-kernel u-boot-sunxi u-boot-tools $PACKAGES"

if [ $ENCRYPT ] ; then
  echo 'aes' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'aes_x86_64' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'aes_generic' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'dm-crypt' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'dm-mod' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'sha256' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'sha256_generic' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'lrw' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'xts' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'crypto_blkcipher' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'gf128mul' >> $TARGET_DIR/etc/initramfs-tools/modules
  echo 'root	/dev/mmcblk0p2	none	luks' >> $TARGET_DIR/etc/crypttab
  echo '/dev/mapper/root	/	ext4	defaults	0	1' > $TARGET_DIR/etc/fstab
  echo '/dev/mmcblk0p1	/boot	ext4	defaults	0	2' >> $TARGET_DIR/etc/fstab
  sed -i -e 's#DEVICE=#DEVICE=eth0#' $TARGET_DIR/etc/initramfs-tools/initramfs.conf
  cp ${REP}/script/initramfs/cryptroot $TARGET_DIR/etc/initramfs-tools/hooks/cryptroot
  cp ${REP}/script/initramfs/openvpn $TARGET_DIR/etc/initramfs-tools/hooks/openvpn
  cp ${REP}/script/initramfs/httpd $TARGET_DIR/etc/initramfs-tools/hooks/httpd
  cp ${REP}/script/initramfs/httpd_start $TARGET_DIR/etc/initramfs-tools/scripts/local-top/httpd
  cp ${REP}/script/initramfs/httpd_stop $TARGET_DIR/etc/initramfs-tools/scripts/local-bottom/httpd
  cp ${REP}/script/initramfs/stunnel $TARGET_DIR/etc/initramfs-tools/hooks/stunnel
  cp ${REP}/script/initramfs/stunnel.conf $TARGET_DIR/etc/initramfs-tools/
  cp ${REP}/script/initramfs/stunnel_start $TARGET_DIR/etc/initramfs-tools/scripts/local-top/stunnel
  cp ${REP}/script/initramfs/stunnel_stop $TARGET_DIR/etc/initramfs-tools/scripts/local-bottom/stunnel
  mkdir -p $TARGET_DIR/etc/initramfs-tools/root
  cp -r ${REP}/script/initramfs/www $TARGET_DIR/etc/initramfs-tools/root/
  chroot_deb $TARGET_DIR "update-initramfs -u -k all"
fi

# Add 'olinux' for root password and force to change it at first login
chroot_deb $TARGET_DIR '(echo olinux;echo olinux;) | passwd root'
chroot_deb $TARGET_DIR 'chage -d 0 root'

# Remove useless files
chroot_deb $TARGET_DIR 'apt-get clean'
rm $TARGET_DIR/etc/resolv.conf

if [ ${CROSS} ] ; then
  rm $TARGET_DIR/usr/bin/qemu-arm-static
fi

if [ ${APTCACHER} ] ; then
  rm $TARGET_DIR/etc/apt/apt.conf.d/01proxy
  cp $TARGET_DIR/tmp/hosts $TARGET_DIR/etc/
fi

finish(){
  exit 0
}

exit 0
