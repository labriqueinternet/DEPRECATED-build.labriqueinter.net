
# Step to Build labriqueinter.net images 

To build Labriqueinter.net directly with [yunohost](https://yunohost.org/) we
cannot use debootstrap with qemu-arm-static because it is buggy and
mysql-server-5.5 installation failed.

The best solution is to build a lightweight image without yunohost, and
perform a full debootstrap with yunohost directly on the olimex board with the
first debootstrap. This process take much time but it the best solution to
build labriqueinter.net entirely with scripts.

# Build the lightweight image

## Debootstrap

### With docker and apt-cacher-ng

```shell
docker build -t debian:olinux -f build/Dockerfile .
mkdir build/apt-cache
docker run -d --name apt -v $(pwd)/build/:/olinux/ debian:olinux /usr/sbin/apt-cacher-ng ForeGround=1 CacheDir=/olinux/apt-cache
docker run --privileged -i -t --name build --link apt:apt -v $(pwd)/build/:/olinux/ debian:olinux bash /olinux/create_arm_debootstrap.sh -c -p apt
docker stop apt
```

### Without docker and without apt-cacher-ng

```shell
sudo bash /olinux/create_arm_debootstrap.sh -c
```

## Install on sd

```shell
sudo bash build/create_device.sh -d img -s 800
sudo dd if=build/olinux.img of=/dev/MYSD
```

## Build all labriqueinter.net images

On your board you should retrieve this git repository and configure the system
for debootstrap. After that you can build labriqueinter.net images. You
probably want to execute the last command on an screen.

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
