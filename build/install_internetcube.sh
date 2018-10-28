#!/bin/bash


set -e
set -x

TARGET_DIR=./tmp
REP=$(dirname $0)
APT='DEBIAN_FRONTEND=noninteractive apt-get install -y --force-yes'
IMAGE=$(echo $1 | sed 's/yunohost/internetcube/')

cp $1 $IMAGE
mkdir -p $TARGET_DIR
umount $TARGET_DIR || true
mount -o loop,offset=4194304 $IMAGE $TARGET_DIR


echo '. /etc/bash_completion' >> $TARGET_DIR/root/.bashrc

# Use dhcp on boot
cat <<EOT > $TARGET_DIR/etc/network/interfaces
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
  post-up ip a a fe80::42:acab/128 dev eth0

auto usb0
allow-hotplug usb0
iface usb0 inet dhcp
EOT

# Debootstrap optimisations from igorpecovnik
# change default I/O scheduler, noop for flash media, deadline for SSD, cfq for mechanical drive
cat <<EOT >> $TARGET_DIR/etc/sysfs.conf
block/mmcblk0/queue/scheduler = noop
#block/sda/queue/scheduler = cfq
EOT

# Add firstrun and secondrun init script
install -m 755 -o root -g root ${REP}/script/resize2fs-reboot $TARGET_DIR/usr/local/bin/
install -m 755 -o root -g root ${REP}/script/hypercube/hypercube.sh $TARGET_DIR/usr/local/bin/
install -m 444 -o root -g root ${REP}/script/resize2fs-reboot.service $TARGET_DIR/etc/systemd/system/
install -m 444 -o root -g root ${REP}/script/hypercube/hypercube.service $TARGET_DIR/etc/systemd/system/
ln -f -s '/etc/systemd/system/multi-user.target.wants/resize2fs-reboot.service' $TARGET_DIR/etc/systemd/system/resize2fs-reboot.service
ln -f -s '/etc/systemd/system/multi-user.target.wants/hypercube.service' $TARGET_DIR/etc/systemd/system/hypercube.service

# Add hypercube scripts
mkdir -p $TARGET_DIR/var/log/hypercube
install -m 444 -o root -g root ${REP}/script/hypercube/install.html $TARGET_DIR/var/log/hypercube/
umount $TARGET_DIR || true

exit 0
