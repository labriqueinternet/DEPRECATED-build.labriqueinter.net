#!/bin/bash

set -e
set -x

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script to create Debian images for olinux boards

# OPTIONS

  -d		yunohost distribution (default: stable)

EOF
exit 1
}

if [[ "$TERM" == "screen"* ]]; then
    echo "your TERM env will pose some problems: '$TERM'."
    echo "Please do export TERM=xterm-color before running this script"
    exit 42
fi

INSTALL_YUNOHOST_DIST='stable'
INSTALL_YUNOHOST_TESTING=
DEBIAN_RELEASE=jessie

while getopts ":d:" opt; do
  case $opt in
    d)
      INSTALL_YUNOHOST_DIST=$OPTARG
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

hostname="yunobuilder"
CONTAINER=${hostname}
LXC_ROOT=/srv/olinux
TARGET_DIR=$LXC_ROOT/${CONTAINER}/rootfs


function _lxc_exec() {
  LC_ALL=C LANGUAGE=C LANG=C lxc-attach  -P ${LXC_ROOT} -n ${CONTAINER} -- /bin/bash -c "$1"
}

if [ "${INSTALL_YUNOHOST_DIST}" != stable ]; then
  INSTALL_YUNOHOST_TESTING="-testing"
fi

systemctl restart apt-cacher-ng

# Build olinux debootstrap with yunohost
./build/create_lxc.sh -d "${INSTALL_YUNOHOST_DIST}" -r "${DEBIAN_RELEASE}" \
 -t /srv/olinux -n "${hostname}" -y -i | tee /srv/olinux/create_lxc.log

boardlist=( 'a20lime' 'a20lime2' )

if test "z${BUILD_ENCRYPTED_IMAGES}" = "zyes"
then
for BOARD in ${boardlist[@]}; do 

  . ./build/config_board.sh
  echo $FLASH_KERNEL > ${TARGET_DIR}/etc/flash-kernel/machine
  _lxc_exec 'update-initramfs -u -k all'
  ./build/create_device.sh -D img -s 1500 \
   -t /srv/olinux/labriqueinternet_${FILE}_encryptedfs_"$(date '+%Y-%m-%d')"_${DEBIAN_RELEASE}${INSTALL_YUNOHOST_TESTING}.img \
   -d ${TARGET_DIR} \
   -b $BOARD

  pushd /srv/olinux/
  tar czf labriqueinternet_${FILE}_encryptedfs_"$(date '+%Y-%m-%d')"_${DEBIAN_RELEASE}${INSTALL_YUNOHOST_TESTING}.img{.tar.xz,}
  popd
  
done
fi

 # Switch to unencrypted root
echo 'LINUX_KERNEL_CMDLINE="console=tty0 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mmcblk0p1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' >  ${TARGET_DIR}/etc/default/flash-kernel
rm -f ${TARGET_DIR}/etc/crypttab
echo '/dev/mmcblk0p1      /	ext4    defaults        0       1' > ${TARGET_DIR}/etc/fstab
  
for BOARD in ${boardlist[@]}; do 

  . ./build/config_board.sh
  echo $FLASH_KERNEL > ${TARGET_DIR}/etc/flash-kernel/machine
  _lxc_exec 'update-initramfs -u -k all'
  ./build/create_device.sh -D img -s 1500 \
   -t /srv/olinux/labriqueinternet_${FILE}_"$(date '+%Y-%m-%d')"_${DEBIAN_RELEASE}${INSTALL_YUNOHOST_TESTING}.img \
   -d ${TARGET_DIR} \
   -b $BOARD
  
  pushd /srv/olinux/
  tar czf labriqueinternet_${FILE}_"$(date '+%Y-%m-%d')"_${DEBIAN_RELEASE}${INSTALL_YUNOHOST_TESTING}.img{.tar.xz,}
  popd

done

exit 0
