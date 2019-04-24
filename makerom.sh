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

if [ ! -d "tools" ]; then
	installtools
fi

