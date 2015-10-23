#!/bin/bash

case $BOARD in
  a20lime2)
    U_BOOT_CONFIG="A20-OLinuXino-Lime2_defconfig"
    DTB="sun7i-a20-olinuxino-lime2.dtb"
    FLASH_KERNEL='Olimex A20-OLinuXino-LIME2'
    U_BOOT='A20-OLinuXino-Lime2'
    ;;
  a20micro)
    U_BOOT_CONFIG="A20-OLinuXino_MICRO_defconfig"
    DTB="sun7i-a20-olinuxino-micro.dtb"
    FLASH_KERNEL='Olimex A20-Olinuxino Micro'
    U_BOOT='A20-OLinuXino_MICRO'
    ;;
  a10lime)
    U_BOOT_CONFIG="A10-OLinuXino-Lime_defconfig"
    DTB="sun7i-a20-olinuxino-lime.dtb"
    FLASH_KERNEL='Olimex A10-OLinuXino-LIME'
    U_BOOT='A10-OLinuXino-Lime'
    ;;
  bananapi)
    FLASH_KERNEL='LeMaker Banana Pi'
    U_BOOT='Bananapi'
    ;;
  *)
    U_BOOT_CONFIG="A20-OLinuXino-Lime_defconfig"
    DTB="sun7i-a20-olinuxino-lime.dtb"
    FLASH_KERNEL='Olimex A20-OLinuXino-LIME'
    U_BOOT='A20-OLinuXino-Lime'
    ;;
esac
