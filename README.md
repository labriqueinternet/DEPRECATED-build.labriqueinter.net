**[BUG REPORTS SHOULD BE OPEN HERE](https://dev.yunohost.org)**

## How to Build

This README describes how we currently build the Internet Cube images. We probably could find a better way, with virtualization and co - but currently, this is how it is done.

### Images to Produce

For now, we support only 2 boards: Olimex LIME and Olimex LIME2. We produce 2 images for each board: for encrypted installations and for non-encrypted ones.

Example of image filenames (e.g. with build on December 1st, 2017 for Debian Jessie):

* LIME non-encrypted: *labriqueinternet_A20LIME_2017-12-01_jessie.img.tar.xz*
* LIME encrypted: *labriqueinternet_A20LIME_encryptedfs_2017-12-01_jessie.img.tar.xz*
* LIME2 non-encrypted: *labriqueinternet_A20LIME2_2017-12-01_jessie.img.tar.xz*
* LIME2 encrypted: *labriqueinternet_A20LIME2_encryptedfs_2017-12-01_jessie.img.tar.xz*

Respecting the format of the filenames is important to ensure the compatibility with *install-sd.sh*.

For generating (optional) GPG signatures, please ask on the *La Brique Internet*'s mailing list.

### Preparing a Dedicated Cube for Building

Choose a dedicated Internet Cube (or just a SD card), and use it to build the four images in the same time. Using a LIME or LIME2 does not matter.

Prepare your building Cube:

```shell
apt-get install git -y --force-yes
git clone https://github.com/labriqueinternet/build.labriqueinter.net.git /opt/build.labriqueinter.net
cd /opt/build.labriqueinter.net && bash init.sh
```

### Images Building

On your building Cube, just do (you should execute this line in a *screen*/*tmux*):

```shell
cd /opt/build.labriqueinter.net && bash build_labriqueinternet_lime.sh
```

After something like 1 hour, the four images produced are available in */srv/olinux/*.

FYOI the stable version of YunoHost is installed by default, but you can use another version (e.g. testing):

```shell
cd /opt/build.labriqueinter.net && bash build_labriqueinternet_lime.sh -d testing
```

### Using Custom *u-boot*

During the images creation (or during the installation, for encrypted versions), this DEB package is download and installed:

 *https://repo.labriqueinter.net/u-boot/u-boot-sunxi_latest_armhf.deb*

This is the official Debian version of *u-boot-sunxi*, but with [some patches](https://github.com/labriqueinternet/build.labriqueinter.net/tree/master/u-boot/patches) specific to LIME/LIME2. If you want to build your own version, or update this one, you just have to execute [this script](https://github.com/labriqueinternet/build.labriqueinter.net/blob/master/u-boot/uboot_makedeb.sh) on your building Cube.

For non-encrypted images: just edit *build/create_arm_debootstrap.sh* on your building Cube, in order to use your version of the DEB package, rather than the online one. Then, rebuild the images.

For encrypted images: no need to rebuild the images. However, you have to edit *install-sd.sh*, in order to use your version of the DEB package, rather than the online one.

### Installing the New Images

Now you can follow [tutorials](https://repo.labriqueinter.net) to install a new Internet Cube.
