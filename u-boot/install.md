# Installing Internet Cube U-boot for LIME/LIME2

## Instructions

**Only for testing!**

Execute the following commands directly on an existing LIME/LIME2 Internet Cube, dedicated to tests.

## Not encrypted cube

### Get new U-boot binaries

Replace the `u-boot-sunxi` package by a custom one:

```
% apt-get remove u-boot-sunxi
% wget -P /tmp/ https://repo.internetcu.be/uboot-tests/u-boot-sunxi_2016.09+dfsg1-2.1_armhf.deb
% dpkg -i /tmp/u-boot-sunxi_2016.09+dfsg1-2.1_armhf.deb
```

### Do U-boot replacement

* LIME1:

```
% dd if=/usr/lib/u-boot/A20-OLinuXino-Lime/u-boot-sunxi-with-spl.bin of=/dev/mmcblk0 bs=1K seek=8
```

or

* LIME2:

```
% dd if=/usr/lib/u-boot/A20-OLinuXino-Lime2/u-boot-sunxi-with-spl.bin of=/dev/mmcblk0 bs=1K seek=8
```

### Reboot

You now just have to reboot your Cube and cross fingers \o/.

```
% systemctl reboot
```

## Encrypted cube

If you have an encrypted cube, you can apply the same procedure as above, only if you created your SD card **with a version of `e2fsprogs` before 1.43** installed on your laptop. If you have used `e2fsprogs` 1.43 or above, you have to recreate your SD card, with the last version of `install-sd.sh` (or with `-O ^metadata_csum,^64bit` option to your `mke2fs` command). For more information, read [this thread](http://lists.denx.de/pipermail/u-boot/2016-July/261415.html).
