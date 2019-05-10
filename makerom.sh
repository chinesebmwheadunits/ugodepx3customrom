#!/bin/bash

filename=""
builddir="build"
toolsdir="tools"
mountdir="$builddir/mnt"
supersudir="supersu"

usage()
{
	echo "Usage: ./makerom.sh -f <px3.img>"
	echo "or"
	echo "./makerom.sh -h"
	echo "for help."
} 

installtools()
{
	mkdir $toolsdir
	echo "Downloading imgRePackerRK"
	wget "https://forum.xda-developers.com/attachment.php?attachmentid=4136650&d=1493819013" -O tools/imgRePackerRK.zip
	unzip $toolsdir/imgRePackerRK.zip -d tools/
	rm $toolsdir/imgRePackerRK.zip
	chmod a+x $toolsdir/imgrepackerrk
}

downloadsupersu()
{
	mkdir $supersudir
	echo "Downloading supersu"
	curl "https://download.chainfire.eu/1220/SuperSU/SR5-SuperSU-v2.82-SR5-20171001224502.zip" > /dev/null 
	wget "https://download.chainfire.eu/1220/SuperSU/SR5-SuperSU-v2.82-SR5-20171001224502.zip?retrieve_file=1" -O $supersudir/supersu.zip
	unzip $supersudir/supersu.zip -d $supersudir/
	rm $supersudir/supersu.zip
}

clean()
{
	rm -rf $builddir/
}

unpack()
{
	$toolsdir/imgrepackerrk $filename
	mv "$filename.dump" $builddir/px3.img.dump/
}

expandsystemimage()
{
	dd if=/dev/zero bs=1M count=64 >> $builddir/px3.img.dump/Image/system.img
	resize2fs $builddir/px3.img.dump/Image/system.img
}

mountsystemimage()
{
	mkdir $mountdir
	mount $builddir/px3.img.dump/Image/system.img $mountdir
}

unmountsystemimage()
{
	if mount | grep $(readlink -f $mountdir) > /dev/null; then
		umount $mountdir
		rmdir $mountdir
	fi
}

setperm()
{
	chown $1:$2 $4
	chmod $3 $4
	if [ "$5" != "" ]; then
		setfattr -n security.selinux -v "$5" $4
	fi
}

lnperm()
{
	ln -s -r $3 $4
	chown -h $1:$2 $4
}

installsupersu()
{
	mkdir $mountdir/app/SuperSU/
	setperm 0 0 0755 $mountdir/app/SuperSU/
	cp $supersudir/common/Superuser.apk $mountdir/app/SuperSU/SuperSU.apk
	setperm 0 0 0644 $mountdir/app/SuperSU/SuperSU.apk "u:object_r:system_file:s0"
	cp $supersudir/common/install-recovery.sh $mountdir/etc/install-recovery.sh
	setperm 0 0 0755 $mountdir/etc/install-recovery.sh "u:object_r:toolbox_exec:s0"
	lnperm 0 0 $mountdir/etc/install-recovery.sh $mountdir/bin/install-recovery.sh
	rm $mountdir/xbin/su
	cp $supersudir/armv7/su $mountdir/xbin/su
	setperm 0 0 0755 $mountdir/xbin/su "u:object_r:system_file:s0"
	mkdir $mountdir/bin/.ext
	setperm 0 0 0777 $mountdir/bin/.ext
	cp $supersudir/armv7/su $mountdir/bin/.ext/.su
	setperm 0 0 0755 $mountdir/bin/.ext/.su "u:object_r:system_file:s0"
	cp $supersudir/armv7/su $mountdir/xbin/daemonsu
	setperm 0 0 0755 $mountdir/xbin/daemonsu "u:object_r:system_file:s0"
	cp $supersudir/armv7/supolicy $mountdir/xbin/supolicy
	setperm 0 0 0755 $mountdir/xbin/supolicy "u:object_r:system_file:s0"
	cp $supersudir/armv7/libsupol.so $mountdir/lib/libsupol.so
	setperm 0 0 0644 $mountdir/lib/libsupol.so "u:object_r:system_file:s0"

	cp $mountdir/bin/app_process32 $mountdir/bin/app_process_init
	setperm 0 2000 0755 $mountdir/bin/app_process_init "u:object_r:system_file:s0"
	mv $mountdir/bin/app_process32 $mountdir/bin/app_process_original
	setperm 0 2000 0755 $mountdir/bin/app_process_original "u:object_r:zygote_exec:s0"
	rm $mountdir/bin/app_process
	lnperm 0 2000 $mountdir/xbin/daemonsu $mountdir/bin/app_process32
	lnperm 0 2000 $mountdir/xbin/daemonsu $mountdir/bin/app_process
	echo 1 > $mountdir/etc/.installed_su_daemon
	setperm 0 0 0644 $mountdir/etc/.installed_su_daemon "u:object_r:system_file:s0"
}

repack()
{
	$toolsdir/imgrepackerrk $builddir/px3.img.dump
	builtimagefile=`realpath $builddir/px3.img`
	echo "Done packing. The resulting image file is $builtimagefile"
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

cd `dirname "$0"`
workingDir=`pwd`

if [ ! -d "$toolsdir" ]; then
	installtools
fi

if [ ! -d "$supersudir" ]; then
	downloadsupersu
fi

if [ -d "$builddir" ]; then
	clean
fi

mkdir $builddir
unpack
expandsystemimage
mountsystemimage
installsupersu
unmountsystemimage
repack

