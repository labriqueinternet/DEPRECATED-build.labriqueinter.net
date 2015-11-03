
# Build on olimex board

## Why ?

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

Log into the olimex board and build, configure it, and run build script (you
probably want to execute the last command on an screen).

```shell
apt-get install git -y --force-yes
git clone https://github.com/labriqueinternet/build.labriqueinter.net.git /opt/build.labriqueinter.net
cd /opt/build.labriqueinter.net && bash init.sh
cd /opt/build.labriqueinter.net && bash build_labriqueinternet_lime.sh
```

Now, if everything gone thind you should have images on /srv/olinux/

### Compress images

If you whant to share your images you probably want to compress them:

```shell
for i in *.img; do tar cfJ $i.tar.xz $i; done
```

# Install 

Now you can follow tutorials to install your [cube](https://repo.labriqueinter.net/).

