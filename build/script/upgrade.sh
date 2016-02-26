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
echo 'LINUX_KERNEL_CMDLINE="console=tty0 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:1280x720p60 root=/dev/mmcblk0p1 rootwait sunxi_ve_mem_reserve=0 sunxi_g2d_mem_reserve=0 sunxi_no_mali_mem_reserve sunxi_fb_mem_reserve=0 panic=10 loglevel=6 consoleblank=0"' >  /etc/default/flash-kernel

if grep -q testing /etc/apt/sources.list ; then
  echo "##################################################################"
  echo "# Warning; you probably doesn't want yunohost testing repository #"
  echo "##################################################################"
  echo "line:"
  grep testing /etc/apt/sources.list
fi
echo 'Please run :'
echo 'apt-get update;apt-get dist-upgrade;apt-get install linux-image-armmp flash-kernel u-boot-sunxi u-boot-tools;apt-get clean'
