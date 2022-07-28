#!/bin/sh

secs=`expr 32 '*' 64`

make_hdimage()
{
	dd if=$TMPDISK of=usrimage bs=$BS count=$USRBLOCKS

	rootsize=`stat -size rootimage`
	usrsize=`stat -size usrimage`

	rootsects=`expr $rootsize / 512`
	usrsects=`expr $usrsize / 512`

	# installboot -m needs at least 1KB 
	dd < /dev/zero >tmpimage count=2
	partition -fm tmpimage 2 81:$rootsects* 0:0 81:$usrsects
	installboot -m tmpimage /usr/mdec/masterboot
	dd < tmpimage > subpart count=1

	primsects=`expr 1 + $rootsects + $usrsects`
	cyl=`expr '(' $primsects ')' / $secs + 1`
	padsects=`expr $cyl \* $secs - 1 - $primsects`

	{ dd < /dev/zero count=1
		cat subpart
		cat rootimage
		cat usrimage
		dd < /dev/zero count=$padsects
	} > hdimage
	partition -m hdimage 81:`expr $primsects + $padsects`*
	installboot -m hdimage /usr/mdec/masterboot
}

hdemu_root_changes()
{
	$RELEASEDIR/usr/bin/installboot -d $RAM \
		$RELEASEDIR/usr/mdec/bootblock boot/boot
	echo \
'label=BIOS
bootcd=2
disable=inet
bios_remap_first=1
ramimagedev=c0d7p0s0
save'	| $RELEASEDIR/usr/bin/edparams $RAM

	echo \
'root=/dev/c0d7p0s0
usr=/dev/c0d7p0s2
usr_roflag="-r"' > $RELEASEDIR/etc/fstab
}

HDEMU=1

COPYITEMS="usr/bin bin usr/lib"
RELEASEDIR=/usr/r
IMAGE=cdfdimage
ROOTIMAGE=rootimage
CDFILES=/usr/tmp/cdreleasefiles
sh tell_config OS_RELEASE . OS_VERSION >/tmp/rel.$$
version_pretty=`sed 's/["      ]//g;/^$/d' </tmp/rel.$$`
version=`sed 's/["      ]//g;/^$/d' </tmp/rel.$$ | tr . _`
ISO=minix${version}_`date +%Y%m%d-%H%M%S`
RAM=/dev/ram
BS=4096

HDEMU=0
COPY=0
CVSTAG=HEAD
CHECKOUTLIST=src

while getopts "sr:ch?" c
do
	case "$c" in
	\?)
		echo "Usage: $0 [-c] [-h] [-r <tag>]" >&2
		exit 1
	;;
	h)
		echo " * Making HD image"
		ISO=${ISO}_bios
		HDEMU=1
		;;
	c)
		echo " * Copying, not CVS"
		COPY=1
		;;
	r)	
		CVSTAG=$OPTARG
		;;
	s)	CHECKOUTLIST="src/LICENSE src/Makefile src/boot src/drivers src/etc src/include src/kernel src/lib src/man src/servers src/test src/tools src/commands/Makefile src/commands/aal src/commands/advent src/commands/ash src/commands/autil src/commands/awk src/commands/bc src/commands/bigmake.inc src/commands/byacc src/commands/cawf src/commands/cron src/commands/de src/commands/dhcpd src/commands/dis88 src/commands/elle src/commands/elvis src/commands/ftp src/commands/ftpd src/commands/ftpd200 src/commands/gzip-1.2.4 src/commands/httpd src/commands/i386 src/commands/i86 src/commands/ibm src/commands/indent src/commands/m4 src/commands/make src/commands/mdb src/commands/mined src/commands/nvi-1.79 src/commands/patch src/commands/ps src/commands/reboot src/commands/rlogind src/commands/scripts src/commands/sh src/commands/simple src/commands/talk src/commands/talkd src/commands/telnet src/commands/telnetd src/commands/urlget src/commands/yap src/commands/zmodem"

		;;
	esac
done

ISO=${ISO}_${CVSTAG}.iso
ISOGZ=${ISO}.gz
echo "Making $ISOGZ"

USRMB=70

USRBLOCKS="`expr $USRMB \* 1024 \* 1024 / $BS`"
USRSECTS="`expr $USRMB \* 1024 \* 2`"
ROOTKB=1400
ROOTSECTS="`expr $ROOTKB \* 2`"
ROOTBLOCKS="`expr $ROOTKB \* 1024 / $BS`"

if [ "$COPY" -ne 1 ]
then
	echo "Note: this script wants to do cvs operations, so it's necessary"
	echo "to have \$CVSROOT set and cvs login done."
	echo ""
fi

TD1=.td1
TD2=.td2

if [ -f $TD1 ]
then	TMPDISK="`cat $TD1`"
else
	echo "Warning: I'm going to mkfs $RAM!"
	echo "It has to be at least $ROOTKB KB."
	echo ""
	echo "Temporary (sub)partition to use to make the /usr FS image? "
	echo "I need $USRMB MB. It will be mkfsed!"
	echo -n "Device: /dev/"
	read dev || exit 1
	TMPDISK=/dev/$dev
fi

if [ -b $TMPDISK ]
then :
else	echo "$TMPDISK is not a block device.."
	exit 1
fi

echo $TMPDISK >$TD1

if [ -f $TD2 ]
then	TMPDISK2="`cat $TD2`"
else
	echo "Temporary (sub)partition to use for /tmp? "
	echo "It will be mkfsed!"
	echo -n "Device: /dev/"
	read dev || exit 1
	TMPDISK2=/dev/$dev
fi

if [ -b $TMPDISK2 ]
then :
else	echo "$TMPDISK2 is not a block device.."
	exit 1
fi

echo $TMPDISK2 >$TD2

umount $TMPDISK
umount $TMPDISK2
umount $RAM

echo " * Cleanup old files"
rm -rf $RELEASEDIR $ISO $IMAGE $ROOTIMAGE $ISOGZ $CDFILES
mkdir -p $CDFILES || exit
mkdir -p $RELEASEDIR
mkfs -B $BS -b $ROOTBLOCKS $RAM || exit
mkfs $TMPDISK2 || exit
echo " * mounting $RAM as $RELEASEDIR"
mount $RAM $RELEASEDIR || exit
mkdir -m 755 $RELEASEDIR/usr
mkdir -m 1777 $RELEASEDIR/tmp
mount $TMPDISK2 $RELEASEDIR/tmp

mkfs -B $BS -b $USRBLOCKS $TMPDISK || exit
echo " * Mounting $TMPDISK as $RELEASEDIR/usr"
mount $TMPDISK $RELEASEDIR/usr || exit
mkdir -p $RELEASEDIR/tmp
mkdir -p $RELEASEDIR/usr/tmp

echo " * Transfering $COPYITEMS to $RELEASEDIR"
( cd / && tar cf - $COPYITEMS ) | ( cd $RELEASEDIR && tar xf - ) || exit 1

# Make sure compilers and libraries are bin-owned
chown -R bin $RELEASEDIR/usr/lib
chmod -R u+w $RELEASEDIR/usr/lib

if [ "$COPY" -ne 1 ]
then
	echo " * Doing new cvs export"
	( cd $RELEASEDIR/usr && mkdir src && cvs export -r$CVSTAG $CHECKOUTLIST )
else
	( cd .. && make clean )
	srcdir=/usr/src
	( cd $srcdir && tar cf - . ) | ( cd $RELEASEDIR/usr && mkdir src && cd src && tar xf - )
fi

echo " * Fixups for owners and modes of dirs and files"
chown -R bin $RELEASEDIR/usr/src $RELEASEDIR/usr/gnu
chmod -R u+w $RELEASEDIR/usr/src $RELEASEDIR/usr/gnu
find $RELEASEDIR/usr/src -type d | xargs chmod 755
find $RELEASEDIR/usr/src -type f | xargs chmod 644
find $RELEASEDIR/usr/src -name configure | xargs chmod 755
find $RELEASEDIR/usr/src/commands -name build | xargs chmod 755
# Bug tracking system not for on cd
rm -rf $RELEASEDIR/usr/src/doc/bugs

# Make sure the CD knows it's a CD
date >$RELEASEDIR/CD
echo " * Chroot build"
chroot $RELEASEDIR "/bin/sh -x /usr/src/tools/chrootmake.sh" || exit 1
echo " * Chroot build done"
# The build process leaves some file in src as root.
chown -R bin $RELEASEDIR/usr/src*
cp issue.install $RELEASEDIR/etc/issue

if [ "$HDEMU" -ne 0 ]; then hdemu_root_changes; fi

echo "Temporary filesystems still mounted. Make changes, or press RETURN"
echo -n "to continue making the image.."
read xyzzy

echo $version_pretty >$RELEASEDIR/etc/version
echo " * Counting files"
df $TMPDISK | tail -1 | awk '{ print $4 }' >$RELEASEDIR/.usrkb
du -s $RELEASEDIR/usr/src.* | awk '{ t += $1 } END { print t }' >$RELEASEDIR/.extrasrckb
( for d in $RELEASEDIR/usr/src.*; do find $d; done) | wc -l >$RELEASEDIR/.extrasrcfiles
find $RELEASEDIR/usr | wc -l >$RELEASEDIR/.usrfiles
find $RELEASEDIR -xdev | wc -l >$RELEASEDIR/.rootfiles
echo " * Scrubbing /.."
cp /dev/zero $RELEASEDIR/.z ; rm $RELEASEDIR/.z
echo " * Scrubbing /usr.."
cp /dev/zero $RELEASEDIR/usr/.z ; rm $RELEASEDIR/usr/.z
echo " * Scrubbing done."
umount $TMPDISK || exit
umount $TMPDISK2 || exit
umount $RAM || exit
(cd ../boot && make)
(cd .. && make depend)
make clean
make image || exit 1
cp image image_big
make clean
make image_small || exit 1
dd if=$RAM of=$ROOTIMAGE bs=$BS count=$ROOTBLOCKS
# Prepare image and image_small for cdfdboot
cp image_big image
sh mkboot cdfdboot
cp $IMAGE $CDFILES/bootflop.img
cp release/cd/* $CDFILES

h_opt=
bootimage=$IMAGE
if [ "$HDEMU" -ne 0 ]; then
	make_hdimage
	h_opt='-h'
	bootimage=hdimage
fi
writeisofs -l MINIX -b $bootimage $h_opt $CDFILES $ISO || exit 1

if [ "$HDEMU" -eq 0 ]
then
	echo "Appending Minix root and usr filesystem"
	# Pad ISO out to cylinder boundary
	isobytes=`stat -size $ISO`
	isosects=`expr $isobytes / 512`
	isopad=`expr $secs - '(' $isosects % $secs ')'`
	dd if=/dev/zero count=$isopad >>$ISO
	# number of sectors
	isosects=`expr $isosects + $isopad`
	( cat $ISO $ROOTIMAGE ; dd if=$TMPDISK bs=$BS count=$USRBLOCKS ) >m
	mv m $ISO
	# Make CD partition table
	installboot -m $ISO /usr/mdec/masterboot
	# Make sure there is no hole..! Otherwise the ISO format is
	# unreadable.
	partition -m $ISO 0 81:$isosects 81:$ROOTSECTS 81:$USRSECTS
fi
echo " * gzipping $ISO"
gzip -9 $ISO
ls -al $ISOGZ

