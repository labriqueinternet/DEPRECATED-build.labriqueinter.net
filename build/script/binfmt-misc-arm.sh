#!/bin/bash
# Script from http://tinkering-is-fun.blogspot.fr/2009/12/running-arm-linux-on-your-desktop-pc_12.html

UNREGISTER=0
if [ "$1" == "unregister" ]; then
    UNREGISTER=1
fi

FORMAT_NAME='arm'
FORMAT_MAGIC='\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00'
FORMAT_MASK='\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff'
FORMAT_INTERP='/usr/bin/qemu-arm-static'

FORMAT_REGISTRATION=":$FORMAT_NAME:M::$FORMAT_MAGIC:$FORMAT_MASK:$FORMAT_INTERP:"

BINFMT_MISC="/proc/sys/fs/binfmt_misc"

if [ $UNREGISTER -ne 1 ]; then
    # Check if format is not registered already
    if [ ! -f "$BINFMT_MISC/$FORMAT_NAME" ]; then
        echo "Registering SH4 binfmt_misc support"
        echo "$FORMAT_REGISTRATION" > /proc/sys/fs/binfmt_misc/register
    else
        echo "Format $FORMAT_NAME already registered."
    fi
else
    # We were asked to drop the registration
    if [ -f "$BINFMT_MISC/$FORMAT_NAME" ]; then
	echo -1 > "$BINFMT_MISC/$FORMAT_NAME"
    else
	echo "Format $FORMAT_NAME not registered."
    fi
fi
