#!/bin/bash

set -e
set -x

show_usage() {
cat <<EOF
# NAME

  $(basename $0) -- Script format device and copy rootfs on it

# OPTIONS

  -b		olinux board (see config_board.sh) 	(default: a20lime)
  -d		debootstrap directory, .img or tarball	(default: /tmp/debootstrap)
  -D		device name (img, /dev/sdc, /dev/mmc)	(mandatory)
  -s		size of img in MB		 	(mandatory only for img device option)
  -t		final image name			(default: /tmp/olinux.img)
  -e		encrypt partition			(default: false)

EOF
exit 1
}

TARGET=./tmp/olinux.img
MNT1=./tmp/dest
MNT2=./tmp/source
DEB_DIR=./tmp/debootstrap
BOARD="a20lime"
REP=$(dirname $0)

while getopts ":s:d:t:b:D:e" opt; do
  case $opt in
    D)
      DEVICE=$OPTARG
      ;;
    s)
      IMGSIZE=$OPTARG
      ;;
    t)
      TARGET=$OPTARG
      ;;
    d)
      DEB_DIR=$OPTARG
      ;;
    b)
      BOARD=$OPTARG
      ;;
    e)
      ENCRYPT=yes
      ;;
    \?)
      show_usage
      ;;
  esac
done

#####################
### CHECKING ARGS ###
#####################

if [ ! -r "${DEB_DIR}" ]; then
  echo "[ERR] Cannot read ${DEB_DIR}" >&2
  exit 1
fi

if [ -z $DEVICE ] ; then
  echo "[ERR] you should provide a device name or img"  >&2
  show_usage
fi

if [ "$DEVICE" = "img" ] && [ -z $IMGSIZE ] ; then
  echo "[ERR] img parameter should come with size parameter"
  show_usage
fi

#####################
### CHECKING BINS ###
#####################

bins=(dd parted mkfs.ext4 zerofree losetup tune2fs)

for i in "${bins[@]}"; do
  if ! which "${i}" &> /dev/null; then
    exit_error "${i} command is required"
  fi
done

######################
### CORE FUNCTIONS ###
######################

mkdir -p $MNT1
mkdir -p $MNT2

if [ "${DEVICE}" = "img" ] ; then
  echo "[INFO] Create image."
  rm -f ${TARGET}
  # create image file
  dd if=/dev/zero of=${TARGET} bs=1MB count=$IMGSIZE status=noxfer >/dev/null 2>&1

  # find first avaliable free device
  DEVICE=$(losetup -f)
  IMGSIZE="100%"
  TYPE="loop"

  # mount image as block device
  losetup $DEVICE ${TARGET}

  sync

elif [ "${DEVICE}" = "qcow" ] ; then
  TYPE="nbd"
  rm -f ${TARGET}
  DEVICE=/dev/nbd0
  qemu-img create -f qcow2 ${TARGET} $IMGSIZE
  qemu-nbd --connect=$DEVICE ${TARGET}
else
  IMGSIZE="100%"
  TYPE="block"
fi

if [ -z $ENCRYPT ] ; then
  # create one partition starting at 2048 which is default
  echo "[INFO] Partitioning"
  parted --script $DEVICE mklabel msdos
  parted --script $DEVICE mkpart primary ext4 2048s ${IMGSIZE}
  parted --script $DEVICE align-check optimal 1
else
  parted --script $DEVICE mklabel msdos
  parted --script $DEVICE mkpart primary ext4 2048s 512MB
  parted --script $DEVICE mkpart primary ext4 512MB ${IMGSIZE}
  parted --script $DEVICE align-check optimal 1
fi

if [[ "${TYPE}" == "loop" || "${DEVICE}" =~ mmcblk[0-9] ]] ; then
  DEVICEP1=${DEVICE}p1
  DEVICEP2=${DEVICE}p2
elif  [ "${TYPE}" == "nbd" ] ; then
  kpartx -as $DEVICE
  DEVICEP1=/dev/mapper/nbd0p1
  DEVICEP2=/dev/mapper/nbd0p2
else
  DEVICEP1=${DEVICE}1
  DEVICEP2=${DEVICE}2
fi

echo "[INFO] Formating"
# create filesystem
mkfs.ext4 $DEVICEP1 >/dev/null 2>&1

# tune filesystem
tune2fs -o journal_data_writeback $DEVICEP1 >/dev/null 2>&1

finish() {
  echo "[INFO] Umount"
  if [ -z $ENCRYPT ] ; then
    if mountpoint -q $MNT1 ; then
      umount $MNT1
    fi
  else
    if mountpoint -q $MNT1 ; then
      umount $MNT1/boot
      umount $MNT1
      cryptsetup luksClose olinux 
    fi
  fi
  if [ "${TYPE}" = "loop" ] ; then
      losetup -d $DEVICE
  elif  [ "${TYPE}" == "nbd" ] ; then
    kpartx -d $DEVICE
    qemu-nbd -d $DEVICE
  fi
}
trap finish EXIT

if [ -z $ENCRYPT ] ; then
  echo "[INFO] Mount filesystem"
  mount -t ext4 $DEVICEP1 $MNT1
else
  echo "[INFO] Format with encryption"
  cryptsetup -y -v luksFormat $DEVICEP2
  cryptsetup luksOpen $DEVICEP2 olinux
  mkfs.ext4 /dev/mapper/olinux >/dev/null 2>&1
  echo "[INFO] Mount filesystem"
  # mount image to already prepared mount point
  mount -t ext4 /dev/mapper/olinux $MNT1
  mkdir	$MNT1/boot
  mount -t ext4 $DEVICEP1 $MNT1/boot
fi  

echo "[INFO] Copy bootstrap files"
cp -ar ${DEB_DIR}/* $MNT1/
sync

echo "[INFO] Write sunxi-with-spl"
. ${REP}/config_board.sh
dd if=$MNT1/usr/lib/u-boot/${U_BOOT}/u-boot-sunxi-with-spl.bin of=${DEVICE} bs=1024 seek=8 >/dev/null 2>&1
sync

if [ -z $ENCRYPT ] ; then
    umount $MNT1
else
    umount $MNT1/boot
    umount $MNT1
    cryptsetup luksClose olinux 
fi

if [ "${TYPE}" = "loop" ] ; then
  echo "[INFO] zerofree"
  zerofree $DEVICEP1  
  if [ $ENCRYPT ] ; then
    zerofree $DEVICEP2 
  fi 
  losetup -d $DEVICE
elif [ "${TYPE}" = "nbd" ] ; then
  kpartx -d $DEVICE
  qemu-nbd -d $DEVICE 
fi

finish() {
  exit 0
}

exit 0
