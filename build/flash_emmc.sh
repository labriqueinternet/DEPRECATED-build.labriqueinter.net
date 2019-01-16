#!/bin/bash
#
# Copyright (c) Authors: http://www.armbian.com/authors
# Adapted by Alex Aubin for the Internet Cube
#
# Tool to transfer the rootfs of an already running Armbian installation from SD card
# to NAND, eMMC, SATA or USB storage. In case of eMMC it's also possible to transfer
# the bootloader to eMMC in a single step so from then on running without SD card is
# possible.

# Import:
# DIR: path to u-boot directory
# write_uboot_platform: function to write u-boot to a block device
[[ -f /usr/lib/u-boot/platform_install.sh ]] && source /usr/lib/u-boot/platform_install.sh

IMAGE=$1

# script configuration
CWD="/usr/lib/nand-sata-install"
EX_LIST="${CWD}/exclude.txt"

# read in board info
[[ -f /etc/armbian-release ]] && source /etc/armbian-release

#recognize_root
root_uuid=$(sed -e 's/^.*root=//' -e 's/ .*$//' < /proc/cmdline)
root_partition=$(blkid | tr -d '":' | grep ${root_uuid} | awk '{print $1}')
root_partition_device="${root_partition::-2}"

# find targets: NAND, EMMC, SATA, SPI
emmccheck=$(ls -d -1 /dev/mmcblk* | grep -w 'mmcblk[0-9]' | grep -v "$root_partition_device");

# Create boot and root file system $1 = boot, $2 = root (Example: create_armbian "/dev/nand1" "/dev/sda3")
create_armbian()
{
	# create mount points, mount and clean
	TempDir=$(mktemp -d /mnt/${0##*/}.XXXXXX || exit 1)
	sync &&	mkdir -p ${TempDir}/bootfs ${TempDir}/rootfs
	[[ -n $2 ]] && ( mount -o compress-force=zlib $2 ${TempDir}/rootfs || mount $2 ${TempDir}/rootfs )
	[[ -n $1 && $1 != "spi" ]] && mount $1 ${TempDir}/bootfs
	rm -rf ${TempDir}/bootfs/* ${TempDir}/rootfs/*

	# sata root part
	# UUID=xxx...
	satauuid=$(blkid -o export $2 | grep -w UUID)

	# SD card boot part -- wrong since more than one entry on various platforms
	# UUID=xxx...
	sduuid=$(blkid -o export /dev/mmcblk*p1 | grep -w UUID | grep -v "$root_partition_device")

	# calculate usage and see if it fits on destination
	USAGE=$(df -BM | grep ^/dev | head -1 | awk '{print $3}' | tr -cd '[0-9]. \n')
	DEST=$(df -BM | grep ^/dev | grep ${TempDir}/rootfs | awk '{print $4}' | tr -cd '[0-9]. \n')
	if [[ $USAGE -gt $DEST ]]; then
        echo "Partition too small. Needed: $USAGE MB Avaliable: $DEST MB"
		umountdevice "$1"; umountdevice "$2"
		exit 1
	fi

	# creating rootfs
	#rsync -avrltD --delete --exclude-from=$EX_LIST / ${TempDir}/rootfs
	echo "Mounting image ..."
	mkdir -p /mnt/image_for_emmc/
	umount /mnt/image_for_emmc/ 2>/dev/null || true
	mount -o loop,offset=4194304 "$IMAGE" /mnt/image_for_emmc
	echo "Running rsync to eMMc ..."
	rsync -arltD --delete --no-inc-recursive --info=progress2 --exclude-from=$EX_LIST /mnt/image_for_emmc/ ${TempDir}/rootfs
	umount /mnt/image_for_emmc/

	# creating fstab from scratch
	echo "Rewriting fstab ..."
	rm -f ${TempDir}/rootfs/etc/fstab
	mkdir -p ${TempDir}/rootfs/etc ${TempDir}/rootfs/media/mmcboot ${TempDir}/rootfs/media/mmcroot

	# Restore TMP and swap
	echo "# <file system>					<mount point>	<type>	<options>							<dump>	<pass>" > ${TempDir}/rootfs/etc/fstab
	echo "tmpfs						/tmp		tmpfs	defaults,nosuid							0	0" >> ${TempDir}/rootfs/etc/fstab
	grep swap /etc/fstab >> ${TempDir}/rootfs/etc/fstab

	# Boot from eMMC, root = eMMC or SATA / USB
	local targetuuid=$emmcuuid
	local choosen_fs=$eMMCFilesystemChoosen
	echo "Finishing full install to eMMC."

	# fix that we can have one exlude file
	cp -R /boot ${TempDir}/bootfs
	# old boot scripts
	sed -e 's,root='"$root_uuid"',root='"$targetuuid"',g' -i ${TempDir}/bootfs/boot/boot.cmd
	# new boot scripts
	if [[ -f ${TempDir}/bootfs/boot/armbianEnv.txt ]]; then
		sed -e 's,rootdev=.*,rootdev='"$targetuuid"',g' -i ${TempDir}/bootfs/boot/armbianEnv.txt
	else
		sed -e 's,setenv rootdev.*,setenv rootdev '"$targetuuid"',g' -i ${TempDir}/bootfs/boot/boot.cmd
		[[ -f ${TempDir}/bootfs/boot/boot.ini ]] && sed -e 's,^setenv rootdev.*$,setenv rootdev "'"$targetuuid"'",' -i ${TempDir}/bootfs/boot/boot.ini
		[[ -f ${TempDir}/rootfs/boot/boot.ini ]] && sed -e 's,^setenv rootdev.*$,setenv rootdev "'"$targetuuid"'",' -i ${TempDir}/rootfs/boot/boot.ini
	fi
	mkimage -C none -A arm -T script -d ${TempDir}/bootfs/boot/boot.cmd ${TempDir}/bootfs/boot/boot.scr	>/dev/null 2>&1 || (echo "Error"; exit 0)

    mountopts='defaults,noatime,nodiratime,commit=600,errors=remount-ro,x-gvfs-hide	0	1'
	# fstab adj
	if [[ "$1" != "$2" ]]; then
		echo "$emmcbootuuid	/media/mmcboot	ext4    $mountopts" >> ${TempDir}/rootfs/etc/fstab
		echo "/media/mmcboot/boot   				/boot		none	bind								0       0" >> ${TempDir}/rootfs/etc/fstab
	fi

	sed -e 's,rootfstype=.*,rootfstype='$choosen_fs',g' -i ${TempDir}/bootfs/boot/armbianEnv.txt
	echo "$targetuuid	/		$choosen_fs	$mountopts" >> ${TempDir}/rootfs/etc/fstab

	if [[ $(type -t write_uboot_platform) != function ]]; then
		echo "Error: no u-boot package found, exiting"
		exit -1
	fi
	write_uboot_platform "$DIR" "$emmccheck"

	umountdevice "/dev/sda"
} # create_armbian


# Accept device as parameter: for example /dev/sda unmounts all their mounts
umountdevice()
{
	if [[ -n $1 ]]; then
		device=$1;
		for n in ${device}*; do
			if [[ $device != "$n" ]]; then
				if mount|grep -q ${n}; then
					umount -l $n >/dev/null 2>&1
				fi
			fi
		done
	fi
} # umountdevice

# formatting eMMC [device] example /dev/mmcblk1 - one can select filesystem type
#
formatemmc()
{
	# choose and create fs
	IFS=" "
	eMMCFilesystemChoosen="ext4"

	# deletes all partitions on eMMC drive
	dd bs=1 seek=446 count=64 if=/dev/zero of=$1 >/dev/null 2>&1
	# calculate capacity and reserve some unused space to ease cloning of the installation
	# to other media 'of the same size' (one sector less and cloning will fail)
	QUOTED_DEVICE=$(echo "${1}" | sed 's:/:\\\/:g')
	CAPACITY=$(parted ${1} unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", \$2 / ( 1024 / \$4 ))}")

	if [[ $CAPACITY -lt 4000000 ]]; then
		# Leave 2 percent unpartitioned when eMMC size is less than 4GB (unlikely)
		LASTSECTOR=$(( 32 * $(parted ${1} unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", ( \$2 * 98 / 3200))}") -1 ))
	else
		# Leave 1 percent unpartitioned
		LASTSECTOR=$(( 32 * $(parted ${1} unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", ( \$2 * 99 / 3200))}") -1 ))
	fi

	echo "Formating $1 to $eMMCFilesystemChoosen ..."
	parted -s $1 -- mklabel msdos
	parted -s $1 -- mkpart primary $eMMCFilesystemChoosen 8192s ${LASTSECTOR}s
	partprobe $1
	mkfs.ext4 -qF $1"p1"
	emmcuuid=$(blkid -o export $1"p1" | grep -w UUID)
	emmcbootuuid=$emmcuuid
}


main()
{
	export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

	IFS="'"
	options=()
	ichip="eMMC";
	dest_boot=$emmccheck"p1"
	dest_root=$emmccheck"p1"

	umountdevice "$emmccheck"
	formatemmc "$emmccheck"
	create_armbian "$dest_boot" "$dest_root"
	umount ${TempDir}/rootfs
	umount ${TempDir}/bootfs

} # main

main "$@"
