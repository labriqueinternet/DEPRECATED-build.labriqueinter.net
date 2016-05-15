#!/bin/bash 

set -xe

KERNEL_VERSION=$(uname -r)

if ! dpkg -l | grep -q linux-image || ! [[ $KERNEL_VERSION =~ ^4\. ]]; then
  echo "Nothing to do" >&2
  exit 1
fi

rm -f /etc/apt/sources.list.d/{testing,backports}.list
rm -f /etc/apt/preferences.d/kernel-{backports,testing}

echo "linux-image-$KERNEL_VERSION linux-image-$KERNEL_VERSION/prerm/removing-running-kernel-$KERNEL_VERSION boolean false" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get remove -y --force-yes --purge linux-image-4* flash-kernel u-boot-tools u-boot-sunxi

if [ -f /etc/crypttab ] ; then
  echo 'LINUX_KERNEL_CMDLINE="console=ttyS1 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mapper/root cryptopts=target=root,source=/dev/mmcblk0p2,cipher=aes-xts-plain64,size=256,hash=sha1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' > /etc/default/flash-kernel
else
  echo 'LINUX_KERNEL_CMDLINE="console=ttyS1 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mmcblk0p1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' > /etc/default/flash-kernel
fi

apt-get clean
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes linux-image-armmp flash-kernel u-boot-sunxi u-boot-tools

update-initramfs -k all -u

exit 0
