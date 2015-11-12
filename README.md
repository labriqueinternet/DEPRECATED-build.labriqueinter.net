# Step to Build labriqueinter.net images 

## With qemu-user 
To build Labriqueinter.net directly with [yunohost](https://yunohost.org/) we
cannot use debootstrap with qemu-arm-static because it is buggy and
mysql-server-5.5 installation failed.

The best solution is to build a lightweight image without yunohost, and
perform a full debootstrap with yunohost directly on the olimex board with the
first debootstrap. This process take much time but it the best solution to
build labriqueinter.net entirely with scripts.

## With qemu-system 
With qemu-arm-system we can directly create images with yunohost. The build
process is compose with tow step; first we create a small VM with the debian
installer and after that we can build all images for labriqueinter.net.

# Build the lightweight image with qemu-user

## Debootstrap

### With docker and apt-cacher-ng

```shell
docker build -t debian:olinux -f build/Dockerfile .
mkdir -p tmp/apt-cache
docker run -d --name apt -v $(pwd)/tmp/:/tmp/ debian:olinux /usr/sbin/apt-cacher-ng ForeGround=1 CacheDir=/tmp/apt-cache
docker run --privileged -i -t --name build --link apt:apt -v $(pwd)/build/:/olinux/ -v $(pwd)/tmp/:/tmp/ debian:olinux bash /olinux/create_arm_debootstrap.sh -c -p apt
docker stop apt
docker rm build
docker rm apt
```

### Without docker and without apt-cacher-ng

```shell
sudo bash /olinux/create_arm_debootstrap.sh -c
```

## Install on sd

```shell
sudo bash build/create_device.sh -D img -s 800
sudo dd if=tmp/olinux.img of=/dev/MYSD
```

# Build the lightweight image with qemu-arm-system

## Install Debian with netinstall

```shell
wget ftp://ftp.debian.org/debian/dists/wheezy/main/installer-armhf/current/images/vexpress/netboot/vmlinuz-3.2.0-4-vexpress
wget ftp://ftp.debian.org/debian/dists/wheezy/main/installer-armhf/current/images/vexpress/netboot/initrd.gz
qemu-img create -f qcow2 hda.img.qcow2 30G
sudo qemu-system-arm -M vexpress-a9 -m 512M -kernel vmlinuz-3.2.0-4-vexpress -initrd initrd.gz -sd  hda.img.qcow2 -append "root=/dev/ram" -no-reboot
```

## Retrieve kernel and start qemu instance

```
sudo modprobe nbd
sudo qemu-nbd -c /dev/nbd0 hda.img.qcow2
sudo kpartx -a /dev/nbd0
sudo mount /dev/mapper/nbd0p2 /mnt
cp /mnt/initrd.img-3.2.0-4-vexpress .
cp /mnt/vmlinuz-3.2.0-4-vexpress .
sudo umount /mnt
sudo kpartx -d /dev/nbd0 
qemu-nbd -d /dev/nbd0
sudo qemu-system-arm -M vexpress-a9 -m 512M -kernel vmlinuz-3.2.0-4-vexpress -initrd initrd.img-3.2.0-4-vexpress -sd hda.img.qcow2 -append "root=/dev/mmcblk0p2" 
```

# Build all labriqueinter.net images

On your board or on your qemu instance you should retrieve this git repository
and configure the system for debootstrap. After that you can build
labriqueinter.net images. You probably want to execute the last command on an
screen.

```shell
apt-get install git -y --force-yes
git clone https://github.com/labriqueinternet/build.labriqueinter.net.git /opt/build.labriqueinter.net
cd /opt/build.labriqueinter.net && bash init.sh
cd /opt/build.labriqueinter.net && bash build_labriqueinternet_lime.sh
```

Now, if everything gone well you should have images on /srv/olinux/ !

# Compress images

If you want to share your images you probably want to compress them:

```shell
for i in *.img; do tar cfJ $i.tar.xz $i; done
```

# Install 

Now you can follow tutorials to install your [cube](https://repo.labriqueinter.net/).
