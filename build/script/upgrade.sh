#!/bin/sh


echo 'Remove pinning from testing'
rm -f /etc/apt/sources.list.d/testing.list
rm -f /etc/apt/preferences.d/kernel-testing

echo 'Install pinning file (/etc/apt/preferences.d/kernel-backports)'
cat <<EOT > ${TARGET_DIR}/etc/apt/preferences.d/kernel-backports
Package: linux-image*
Pin: release a=jessie-backports
Pin-Priority: 990

Package: u-boot*
Pin: release a=jessie-backports
Pin-Priority: 990

Package: flash-kernel*
Pin: release a=jessie-backports
Pin-Priority: 990

Package: *
Pin: release a=jessie-backports
Pin-Priority: 50
EOT

echo 'Install Debian backports sources (/etc/apt/sources.list.d/backports.list)'
cat <<EOF > /etc/apt/sources.list.d/backports.list
deb http://ftp.fr.debian.org/debian jessie-backports main
EOF

echo 'Configure flash-kernel'
if [ -f "/etc/crypttab" ]; then
  echo 'LINUX_KERNEL_CMDLINE="console=ttyS1 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mapper/root cryptopts=target=root,source=/dev/mmcblk0p2,cipher=aes-xts-plain64,size=256,hash=sha1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' > /etc/default/flash-kernel
else
  echo 'LINUX_KERNEL_CMDLINE="console=tty0 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mmcblk0p1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' >  /etc/default/flash-kernel
fi

YUNOHOST_SOURCES='/etc/apt/sources.list.d/yunohost.list'
if grep -q testing "${YUNOHOST_SOURCES}" ; then
  echo "##################################################################"
  echo "# Warning; you probably doesn't want yunohost testing repository #"
  echo "##################################################################"
  echo "line:"
  grep testing "${YUNOHOST_SOURCES}"
fi
echo 'Now you can run (answer no, and type enter twice):'
echo 'apt-get update'
echo 'apt-get dist-upgrade'
echo 'apt-get install linux-image-armmp flash-kernel u-boot-sunxi u-boot-tools'
echo 'apt-get clean'
