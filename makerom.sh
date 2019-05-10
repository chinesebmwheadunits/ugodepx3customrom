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
	if [ $? -ne 0 ]; then
		echo "Unzip of imgRepackerRK failed."
		return 1
	fi
	rm $toolsdir/imgRePackerRK.zip
	chmod a+x $toolsdir/imgrepackerrk
}

downloadsupersu()
{
	mkdir $supersudir
	echo "Downloading supersu"
	wget -qO- "https://download.chainfire.eu/1220/SuperSU/SR5-SuperSU-v2.82-SR5-20171001224502.zip" &> /dev/null 
	wget "https://download.chainfire.eu/1220/SuperSU/SR5-SuperSU-v2.82-SR5-20171001224502.zip?retrieve_file=1" -O $supersudir/supersu.zip
	unzip $supersudir/supersu.zip -d $supersudir/
	if [ $? -ne 0 ]; then
		echo "Unzip of superSU failed."
		return 1
	fi
	rm $supersudir/supersu.zip
}

clean()
{
	if ! rm -rf $builddir/; then
		echo "Cleaning of the build directory failed"
		return 1
	fi
}

unpack()
{
	$toolsdir/imgrepackerrk $filename
	if [ $? -ne 0 ]; then
		echo "ImgRepacker unpacking of $filename failed."
		return 1
	fi
	mv "$filename.dump" $builddir/px3.img.dump/
}

expandsystemimage()
{
	dd if=/dev/zero bs=1M count=64 >> $builddir/px3.img.dump/Image/system.img
	if ! resize2fs $builddir/px3.img.dump/Image/system.img; then
		echo "Resize of the system image failed."
		return 1
	fi
}

mountsystemimage()
{
	mkdir $mountdir
	if ! mount $builddir/px3.img.dump/Image/system.img $mountdir; then
		echo "Mount of the system image (ext2fs) failed."
		return 1
	fi
}

unmountsystemimage()
{
	if mount | grep $(readlink -f $mountdir) > /dev/null; then
		cd $1
		sync
		sleep 1
		if ! umount $mountdir; then
			echo "Unmounting $mountdir failed"
			return 1
		fi
		rmdir $mountdir
		echo "Unmounted $mountdir"
	fi
}

setperm()
{
	chown $1:$2 $4
	chmod $3 $4
	if [ "$5" != "" ]; then
		if ! setfattr -n security.selinux -v "$5" $4; then
			echo "Setting extended attributes on $4 failed"
			return 1
		fi
	fi
}

lnperm()
{
	if ! ln -s -r $3 $4; then
		echo "Creating sym link $4 failed"
		return 1
	fi
	chown -h $1:$2 $4
}

installsupersu()
{
	mkdir $mountdir/app/SuperSU/
	if ! setperm 0 0 0755 $mountdir/app/SuperSU/; then
		return 1
	fi
	cp $supersudir/common/Superuser.apk $mountdir/app/SuperSU/SuperSU.apk
	if ! setperm 0 0 0644 $mountdir/app/SuperSU/SuperSU.apk "u:object_r:system_file:s0"; then
		return 1
	fi
	cp $supersudir/common/install-recovery.sh $mountdir/etc/install-recovery.sh
	if ! setperm 0 0 0755 $mountdir/etc/install-recovery.sh "u:object_r:toolbox_exec:s0"; then
		return 1
	fi
	if ! lnperm 0 0 $mountdir/etc/install-recovery.sh $mountdir/bin/install-recovery.sh; then
		return 1
	fi
	rm $mountdir/xbin/su
	cp $supersudir/armv7/su $mountdir/xbin/su
	if ! setperm 0 0 0755 $mountdir/xbin/su "u:object_r:system_file:s0"; then
		return 1
	fi
	mkdir $mountdir/bin/.ext
	if ! setperm 0 0 0777 $mountdir/bin/.ext; then
		return 1
	fi
	cp $supersudir/armv7/su $mountdir/bin/.ext/.su
	if ! setperm 0 0 0755 $mountdir/bin/.ext/.su "u:object_r:system_file:s0"; then
		return 1
	fi
	cp $supersudir/armv7/su $mountdir/xbin/daemonsu
	if ! setperm 0 0 0755 $mountdir/xbin/daemonsu "u:object_r:system_file:s0"; then
		return 1
	fi
	cp $supersudir/armv7/supolicy $mountdir/xbin/supolicy
	if ! setperm 0 0 0755 $mountdir/xbin/supolicy "u:object_r:system_file:s0"; then
		return 1
	fi
	cp $supersudir/armv7/libsupol.so $mountdir/lib/libsupol.so
	if ! setperm 0 0 0644 $mountdir/lib/libsupol.so "u:object_r:system_file:s0"; then
		return 1
	fi

	cp $mountdir/bin/app_process32 $mountdir/bin/app_process_init
	if ! setperm 0 2000 0755 $mountdir/bin/app_process_init "u:object_r:system_file:s0"; then
		return 1
	fi
	mv $mountdir/bin/app_process32 $mountdir/bin/app_process_original
	if ! setperm 0 2000 0755 $mountdir/bin/app_process_original "u:object_r:zygote_exec:s0"; then
		return 1
	fi
	rm $mountdir/bin/app_process
	if ! lnperm 0 2000 $mountdir/xbin/daemonsu $mountdir/bin/app_process32; then
		return 1
	fi
	if ! lnperm 0 2000 $mountdir/xbin/daemonsu $mountdir/bin/app_process; then
		return 1
	fi
	echo 1 > $mountdir/etc/.installed_su_daemon
	if ! setperm 0 0 0644 $mountdir/etc/.installed_su_daemon "u:object_r:system_file:s0"; then
		return 1
	fi
}

repack()
{
	$toolsdir/imgrepackerrk $builddir/px3.img.dump
	if [ $? -ne 0 ]; then
		echo "ImgRepacker repacking of $builddir/px3.img.dump failed."
		return 1
	fi
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

if !hash wget 2>/dev/null; then
	echo "Please install wget"
	exit 1
fi

if !hash resize2fs 2>/dev/null; then
	echo "Please install e2fsprogs (resize2fs)"
	exit 1
fi

if !hash setfattr 2>/dev/null; then
	echo "Please install attr (setfattr)"
	exit 1
fi

cd `dirname "$0"`
workingdir=`pwd`

if [ ! -d "$toolsdir" ]; then
	if ! installtools; then
		rm -rf "$toolsdir"
		exit 1
	fi
fi

if [ ! -d "$supersudir" ]; then
	if ! downloadsupersu; then
		rm -rf "$supersudir"
		exit 1
	fi
fi

if [ -d "$builddir" ]; then
	if ! clean; then
		exit 1
	fi
fi

mkdir $builddir
if ! unpack; then
	exit 1
fi
if ! expandsystemimage; then
	rm -rf "$builddir/px3.img.dump"
	exit 1
fi
if ! mountsystemimage; then
	rmdir "$mountdir"
	exit 1
fi
if ! installsupersu; then
	unmountsystemimage $workingdir
	rm -rf "$builddir/px3.img.dump"
	exit 1
fi
if ! unmountsystemimage $workingdir; then
	echo "Please unmount $mountdir manually"
	exit 1
fi
if ! repack; then
	rm -rf "$builddir/px3.img.dump"
	exit 1
fi

