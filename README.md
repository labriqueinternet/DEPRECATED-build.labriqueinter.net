# build.labriqueinter.net

## Build on olimex board

### Why ?

To build Labriqueinter.net directly with [yunohost](https://yunohost.org/) we
cannot use debootstrap with qemu-arm because mysql-server-5.5 is buggy and the
installation failed. 

The best solution compiling the kernel and perform a debootstrap on a olimex
board. This process take much time but it the best solution to build
labriqueinter.net entirely with scripts. 

## How ?

On your fresh olimex installation (build with
[sunxi-debian](https://github.com/bleuchtang/sunxi-debian) for instance)

### Retrieve scripts

```shell
apt-get install git
git clone https://github.com/bleuchtang/build.labriqueinter.net.git /opt/build.labriqueinter.net
```

### Prepare Debian for compilation and debootstrap

```shell
cd /opt/build.labriqueinter.net && bash init.sh
```

### Build labriqueinter.net rootfs and u-boot

```shell
cd /opt/build.labriqueinter.net && bash build_labriqueinternet_lime.sh
``` 

### Create image file

Partitioning on loop device seems not work on my board. So we should retrieve
the tarball on your local machine and create device. 

On your computer:

```shell
git clone https://github.com/bleuchtang/sunxi-debian.git && cd sunxi-debian
scp root@myolimex:/srv/olinux/yunohost_lime.tar .
scp root@myolimex:/srv/olinux/sunxi/u-boot/u-boot-sunxi-with-spl.bin .
sudo bash olinux/create_device.sh -d img -s 1200 -t yunohost_lime.img -b ./yunohost_lime.tar -u ./u-boot-sunxi-with-spl.bin
```
 
## Build with cross compilation and cross debootstrap

/!\ Warning: with this method you cannot perform a debootstrap with yunohost
directly.

See [sunxi-debian](https://github.com/bleuchtang/sunxi-debian)
