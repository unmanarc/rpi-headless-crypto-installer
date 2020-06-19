#!/bin/bash

# Ubuntu remote full disk encryption.
# Supported Version: Ubuntu 20.04LTS

# Author: Aaron G. Mizrachi P. <admin@unmanarc.com> (C) 2017-2020
# License: MIT

# Thanks to https://carlo-hamalainen.net/2017/03/12/raspbian-with-full-disk-encryption/
# Thanks to https://docs.kali.org/kali-dojo/04-raspberry-pi-with-luks-disk-encryption
# Thanks to https://hamy.io/post/0005/remote-unlocking-of-luks-encrypted-root-in-ubuntu-debian/
# Thanks to https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux

Color_Off='\033[0m'       # Text Reset
# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White
# High Intensity
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White
BIWhite='\033[1;97m'      # White

function cleanup()
{
	echo -ne "${BIWhite}[+] Cleaning up..."
	umount /tmp/rpisystem/proc /tmp/rpisystem/sys &> /dev/null
	umount /tmp/rpisystem/dev/pts /tmp/rpisystem/dev &> /dev/null
	umount /tmp/rpisystem/boot/firmware &> /dev/null
	umount /tmp/rpisystem &> /dev/null
	cryptsetup luksClose crypt_sdcard &> /dev/null
	sync &> /dev/null
	echo -e "OK${Color_Off}"
}

function usage()
{
	printf "Usage: %s /dev/sdX \n" "$0" 1>&2
        printf "\n" 1>&2
	printf "> /dev/sdX is the target (eg. /dev/sdf)\n" 1>&2
	printf "\n" 1>&2
}

function banner()
{
	echo -e "${IGreen}Ubuntu RootFS Encryption Shell (Raspbbery Disk Encryption) v1.0${Color_Off}"
	printf "Done by Aaron G. Mizrachi P. <admin@unmanarc.com>, License: MIT\n"
	printf "\n"
}

banner

if [ "$(which qemu-arm-static)" = "" ]; then
        echo "You need to install qemu-user-static before running this."
        exit
fi

if [ "$1" = "help" ] || [ "$1" = "" ]; then
	usage
	exit
fi

TARGET_DEV="$1"


TARGET_PART1="${TARGET_DEV}1"
TARGET_PART2="${TARGET_DEV}2"

if [ "$(echo ${TARGET_DEV} | grep mmcblk)" != ""  ]; then
        TARGET_PART2="${TARGET_DEV}p2"
        TARGET_PART1="${TARGET_DEV}p1"
fi


YES=

clear

echo -e "${BIWhite}[+] Opening the encrypted container${Color_Off}"
cryptsetup luksOpen "${TARGET_PART2}" crypt_sdcard
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup 
        exit
fi

mkdir -p /tmp/rpisystem
echo -e "${BIWhite}[+] Mounting the rootfs from image into /tmp/rpisystem${Color_Off}"
mount /dev/mapper/crypt_sdcard /tmp/rpisystem
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup 
        exit
fi

echo -e "${BIWhite}[+] Mounting the firmware boot from sdcard into /tmp/rpisystem/boot/firmware${Color_Off}"
mount "${TARGET_PART1}" /tmp/rpisystem/boot/firmware
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup
        exit
fi

echo -e "${BIWhite}[+] Mounting proc,sys,dev,dev/pts${Color_Off}"
mount -t proc none /tmp/rpisystem/proc
mount -t sysfs none /tmp/rpisystem/sys
mount -o bind /dev      /tmp/rpisystem/dev
mount -o bind /dev/pts  /tmp/rpisystem/dev/pts
cp /usr/bin/qemu-arm-static /tmp/rpisystem/usr/bin/ &> /dev/null

#cat << 'EOF' >> /tmp/rpisystem/update.sh
#echo building initramfs...
#mkinitramfs -v -o /boot/initramfs.gz "${KERNELVER}"
#EOF

echo -e "${BIWhite}[+] Entering to target system${Color_Off}"
echo
echo "---------------------------------------------------------------------------"
echo "This is the raspberry system:"
echo "You can use this shell to install your rpi stuff!"
echo "Recommended things: change pi password, enable ssh, etc..."
echo "Type 'exit' command to finish the installation"
echo "---------------------------------------------------------------------------"
LANG=C chroot /tmp/rpisystem /bin/su -
cleanup

clear
echo
echo "REMOVE THE SDCARD FROM YOUR COMPUTER AND INSERT IT INTO YOUR RASPBERRY PI"
