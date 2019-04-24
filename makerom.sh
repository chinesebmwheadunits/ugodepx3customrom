#!/bin/bash

filename=""

usage()
{
	echo "Usage: ./makerom.sh -f <px3.img>"
	echo "or"
	echo "./makerom.sh -h"
	echo "for help."
} 

installtools()
{
	mkdir tools
	echo "Downloading imgRePackerRK"
	wget "https://forum.xda-developers.com/attachment.php?attachmentid=4136650&d=1493819013" -O tools/imgRePackerRK.zip
	unzip tools/imgRePackerRK.zip -d tools/
	rm tools/imgRePackerRK.zip
	chmod a+x tools/imgrepackerrk
}

clean()
{
	rm -rf build/
}

unpack()
{
	./tools/imgrepackerrk $filename
	mv "$filename.dump" ./build/px3.img.dump/
}

expandsystemimage()
{
	dd if=/dev/zero bs=1M count=64 >> ./build/px3.img.dump/Image/system.img
	resize2fs ./build/px3.img.dump/Image/system.img
}

mountsystemimage()
{
	mkdir ./build/mnt
	mount ./build/px3.img.dump/Image/system.img ./build/mnt
}

unmountsystemimage()
{
	if mount | grep $(readlink -f ./build/mnt) > /dev/null; then
		umount ./build/mnt
		rmdir ./build/mnt
	fi
}

while [ "$1" != "" ]; do
    case $1 in
        -f | --file )           shift
                                filename=$1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

if [ ! -f "$filename" ]; then
	usage
	exit 1
fi

if [[ $(id -u) -ne 0 ]]; then
	usage
	echo "Please run this script as root"
	exit 1
fi

if [ ! -d "tools" ]; then
	installtools
fi

if [ -d "build" ]; then
	clean
fi

mkdir build
unpack
expandsystemimage
mountsystemimage
unmountsystemimage
