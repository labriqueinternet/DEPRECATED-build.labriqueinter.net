# Step to Build labriqueinter.net images 

## With your board 
To build Labriqueinter.net directly with [yunohost](https://yunohost.org/) we
cannot use debootstrap with qemu-arm-static because it is buggy and
mysql-server-5.5 installation failed.

the first solution is to build a lightweight image without yunohost, and
perform a full debootstrap with yunohost directly on the olimex board with the
first debootstrap.

## With qemu-system-arm 
With qemu-arm-system we can directly create images without a board. The build
process is compose with tow step; first, like above, we create a lightweight
debian image with debootstrap and then we can build full image inside a qemu
instane.

# Build the lightweight image 

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

## Install on sd for the board

```shell
sudo bash build/create_device.sh -D img -s 800
sudo dd if=tmp/olinux.img of=/dev/MYSD
```

## Create a Qcow image for qemu/libvirt

```shell
sudo bash build/create_device.sh -D qcow -s 10G
```
 
#  Start the lightweight image with qemu-arm-system

```shell
wget http://ftp.nl.debian.org/debian/dists/jessie/main/installer-armhf/current/images/device-tree/vexpress-v2p-ca15-tc1.dtb -O tmp/vexpress-v2p-ca15-tc1.dtb 
sudo qemu-system-arm -m 1024M -drive if=none,file=olinux.img,cache=writeback,id=foo -device virtio-blk-device,drive=foo -M vexpress-a15 -dtb tmp/vexpress-v2p-ca15-tc1.dtb -kernel tmp/debootstrap/boot/vmlinuz-4.2.0-0.bpo.1-armmp -initrd tmp/debootstrap/boot/initrd.img-4.2.0-0.bpo.1-armmp -append "root=/dev/vda1 console=ttyAMA0 earlycon" -no-reboot -nographic
```
#  Start the lightweight image with libvirt

```shell
wget http://ftp.nl.debian.org/debian/dists/jessie/main/installer-armhf/current/images/device-tree/vexpress-v2p-ca15-tc1.dtb -O tmp/vexpress-v2p-ca15-tc1.dtb 
sudo virt-install --name olinux --memory 1024 --disk path=$(pwd)/tmp/olinux.img,bus=virtio --arch armv7l --machine vexpress-a15 --boot kernel=$(pwd)/tmp/debootstrap/boot/vmlinuz-4.2.0-0.bpo.1-armmp,initrd=$(pwd)/tmp/debootstrap/boot/initrd.img-4.2.0-0.bpo.1-armmp,dtb=$(pwd)/tmp/vexpress-v2p-ca15-tc1.dtb,kernel_args="root=/dev/vda1 console=ttyAMA0 earlycon" --nographics --network=bridge=br0
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
