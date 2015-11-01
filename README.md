# build.labriqueinter.net

## Build on olimex board

### Why ?

To build Labriqueinter.net directly with [yunohost](https://yunohost.org/) we
cannot use debootstrap with qemu-arm because mysql-server-5.5 is buggy and the
installation failed.

The best solution is to build a lightweight image without yunohost, and
perform a full debootstrap with yunohost directly on the olimex board with the
first debootstrap. This process take much time but it the best solution to
build labriqueinter.net entirely with scripts.

## How ?

### Build the first lightweight image

```shell
docker run --privileged -i -t -v $(pwd)/build/:/olinux/ debian:olinux bash /olinux/create_arm_debootstrap.sh -c -b lime2 
sudo bash build/create_device.sh -d img -s 800
```

Now copy build/olimex.img on the sd and boot on it.

### Build all labriqueinter.net images

Log into the olimex board and build, configure it, and run build script.

```shell
apt-get install git -y --force-yes
git clone https://github.com/labriqueinternet/build.labriqueinter.net.git /opt/build.labriqueinter.net
cd /opt/build.labriqueinter.net && bash init.sh
cd /opt/build.labriqueinter.net && bash build_labriqueinternet_lime.sh
```

Now, if everything gone thind you should have images on /srv/olinux/
