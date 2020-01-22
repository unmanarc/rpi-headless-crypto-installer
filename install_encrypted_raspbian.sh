#!/bin/bash

# Raspbian remote full disk encryption.

# Author: Aaron G. Mizrachi P. <admin@unmanarc.com> (C) 2017-2020
# License: MIT

# Thanks to https://carlo-hamalainen.net/2017/03/12/raspbian-with-full-disk-encryption/
# Thanks to https://docs.kali.org/kali-dojo/04-raspberry-pi-with-luks-disk-encryption
# Thanks to https://hamy.io/post/0005/remote-unlocking-of-luks-encrypted-root-in-ubuntu-debian/
# Thanks to https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux

##################################################################
# Configurable parameters...
DROPBEAR_OPTIONS="-s -j -k -I 60 -p 5022"
LUKS_FORMAT_OPTIONS="--cipher=aes-xts-plain64 --key-size=512 --hash=sha256 --use-random"
##################################################################

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
	umount /tmp/rpisystem/boot &> /dev/null
	umount /tmp/rpisystem &> /dev/null
	cryptsetup luksClose crypt_sdcard &> /dev/null
	kpartx -d "${1}" &> /dev/null
	sync &> /dev/null
	echo -e "OK${Color_Off}"
}

function usage()
{
	printf "Usage: %s raspbian_original.img /dev/sdX id_rsa.pub\n" "$0" 1>&2
        printf "\n" 1>&2
	printf "> raspbian_original.img is the Raspbian Image\n" 1>&2
	printf "> /dev/sdX is the target (eg. /dev/sdf)\n" 1>&2
        printf "> id_rsa.pub is your public SSH key\n" 1>&2
	printf "\n" 1>&2
}

function banner()
{
	echo -e "${IGreen}Raspbian RootFS Encryption (Raspbbery Disk Encryption) v1.0${Color_Off}"
	printf "Done by Aaron G. Mizrachi P. <admin@unmanarc.com>, License: MIT\n"
	printf "\n"
}

banner

if [ "$(which partclone.ext4)" = "" ]; then
        echo "You need to install partclone before running this."
        exit
fi

if [ "$(which pv)" = "" ]; then
        echo "You need to install pv before running this."
        exit
fi

if [ "$(which parted)" = "" ]; then
        echo "You need to install parted before running this."
        exit
fi

if [ "$(which partprobe)" = "" ]; then
        echo "You need to install parted before running this."
        exit
fi

if [ "$(which kpartx)" = "" ]; then
        echo "You need to install kpartx before running this."
	exit
fi

if [ "$(which qemu-arm-static)" = "" ]; then
        echo "You need to install qemu-user-static before running this."
        exit
fi

if [ "$1" = "help" ] || [ "$1" = "" ] || [ "$2" = "" ] || [ "$3" = "" ]; then
	usage
	exit
fi

TARGET_IMG="${1}"
TARGET_DEV="$2"
PUBKEY="$3"

if [ ! -e "$PUBKEY" ]; then
        printf "ERROR: SSH public key does not exist\n" 1>&2
        usage
        exit
fi

if [ ! -e "$TARGET_IMG" ]; then
	printf "ERROR: Base image does not exist\n" 1>&2
	usage
	exit
fi

clear
echo "------------------- Security Warning -------------------"
echo
echo "   This image could access/modify your system as root   "
echo "         Do you trust this image comes from             "
echo "          a secure and legitimate source?               "
echo
echo "--------------------------------------------------------"
echo -n "Write YES to accept> "
read YES
if [ "${YES}" != "YES" ]; then
        echo "Aborted."
        exit
fi      
YES=

clear
echo "----------------- TARGET DEVICE IS --------------------"
lsblk "${TARGET_DEV}" 
echo "-------------------------------------------------------"
#sha256sum "${TARGET_IMG}"
echo
echo "The target will be wiped out causing potential data"
echo "loss, this should not affect any other partition"
echo "however, a full system backup is recommended."
echo
echo -n "Write YES to accept> "
read YES
if [ "${YES}" != "YES" ]; then
	echo "Aborted."
	exit
fi
YES=

clear
echo "-------------------------------------------------------"
LOOPDEV='/dev/mapper/'$(kpartx -av "${TARGET_IMG}" | cut -d' ' -f3 | head -1 | grep -o ^loop[0-9]* )
FIRST_BYTES=$(parted "${TARGET_IMG}" -s unit b print | grep fat32 | head -1 | awk '{ print $2 }' | sed 's/B$//g')

echo -e "${BIWhite}[+] Writting the first ${FIRST_BYTES} bytes from image to ${TARGET_DEV}...${Color_Off}"
dd if="${TARGET_IMG}" of="${TARGET_DEV}" bs=1 count=${FIRST_BYTES} &> /dev/null
if [ "$?" != "0" ]; then
	echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
	cleanup "${TARGET_IMG}"
	exit
fi
partprobe "${TARGET_DEV}" &> /dev/null

echo -e "${BIWhite}[+] Wiping any previous installation metadata${Color_Off}"
dd if=/dev/urandom of="${TARGET_DEV}2" bs=1M count=8 &> /dev/null
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup "${TARGET_IMG}"
        exit
fi

echo -e "${BIWhite}[+] Resizing the last partition${Color_Off}"
parted "${TARGET_DEV}" resizepart 2 100%
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup "${TARGET_IMG}"
        exit
fi
partprobe "${TARGET_DEV}" &> /dev/null

echo -e "${BIWhite}[+] Creating the encrypted container${Color_Off}"
cryptsetup --force-password -q -v ${LUKS_FORMAT_OPTIONS} luksFormat "${TARGET_DEV}2"
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup "${TARGET_IMG}"
        exit
fi

echo -e "${BIWhite}[+] Opening the encrypted container${Color_Off}"
cryptsetup luksOpen "${TARGET_DEV}2" crypt_sdcard
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup "${TARGET_IMG}"
        exit
fi

echo -e "${BIWhite}[+] Copying the boot partition from ${TARGET_IMG} to ${TARGET_DEV}1${Color_Off}"
partclone.fat32 --dev-to-dev --source "${LOOPDEV}p1" -O "${TARGET_DEV}1"

echo -e "${BIWhite}[+] Copying the root partition from ${TARGET_IMG} to /dev/mapper/crypt_sdcard${Color_Off}"
partclone.ext4 --dev-to-dev --source "${LOOPDEV}p2" -O /dev/mapper/crypt_sdcard

echo -e "${BIWhite}[+] Resizing the root partition to sdcard size${Color_Off}"
e2fsck -y -f /dev/mapper/crypt_sdcard  &> /dev/null
resize2fs /dev/mapper/crypt_sdcard &> /dev/null
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup "${TARGET_IMG}"
        exit
fi

mkdir -p /tmp/rpisystem
echo -e "${BIWhite}[+] Mounting the rootfs from image into /tmp/rpisystem${Color_Off}"
mount /dev/mapper/crypt_sdcard /tmp/rpisystem
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup "${TARGET_IMG}"
        exit
fi

echo -e "${BIWhite}[+] Mounting the boot from sdcard into /tmp/rpisystem/boot${Color_Off}"
mount "${TARGET_DEV}1" /tmp/rpisystem/boot
if [ "$?" != "0" ]; then
        echo -e "${BIWhite}[+] Error: aborting.${Color_Off}"
        cleanup "${TARGET_IMG}"
        exit
fi

echo -e "${BIWhite}[+] Fixing ld.so.preload${Color_Off}"
sed -i 's/\/usr\/lib/#\/usr\/lib/g' /tmp/rpisystem/etc/ld.so.preload

echo -e "${BIWhite}[+] Mounting proc,sys,dev,dev/pts${Color_Off}"
mount -t proc none /tmp/rpisystem/proc
mount -t sysfs none /tmp/rpisystem/sys
mount -o bind /dev      /tmp/rpisystem/dev
mount -o bind /dev/pts  /tmp/rpisystem/dev/pts
cp /usr/bin/qemu-arm-static /tmp/rpisystem/usr/bin/ &> /dev/null

echo -e "${BIWhite}[+] Copying the authorized key${Color_Off}"
#printf "command=\"/lib/cryptsetup/askpass 'Enter luks password:' > /lib/cryptsetup/passfifo\" " > /tmp/rpisystem/authorized_keys 
#rintf "no-port-forwarding,no-agent-forwarding,no-x11-forwarding,command=\"/scripts/local-top/cryptroot && kill -9 \`ps | grep -m 1 'cryptroot' | cut -d ' ' -f 3\`\" " > /tmp/rpisystem/authorized_keys

# Restrictions:
#printf 'no-port-forwarding,no-agent-forwarding,no-x11-forwarding,command="PATH=$PATH:/usr/sbin:/sbin /scripts/local-top/cryptroot && kill -9 `ps | grep -m 1 '\''cryptroot'\'' | cut -d '\'' '\'' -f 3`" ' > /tmp/rpisystem/authorized_keys
printf 'no-port-forwarding,no-agent-forwarding,no-x11-forwarding,command="cryptroot-unlock" ' > /tmp/rpisystem/authorized_keys

cat "${PUBKEY}" >> /tmp/rpisystem/authorized_keys
chmod 600 /tmp/rpisystem/authorized_keys

cat << 'EOF' | install -m 700 /dev/stdin /tmp/rpisystem/update.sh
#!/bin/bash

apt update
apt -y install busybox cryptsetup dropbear
sed -i 's| init=/usr/lib/raspi-config/init_resize\.sh||' /boot/cmdline.txt
sed -i 's/root\=.*\ /root=\/dev\/mapper\/crypt_sdcard cryptdevice=\/dev\/mmcblk0p2:crypt_sdcard rootfstype=ext4 elevator=noop fsck.repair=yes rootwait ip=:::::eth0:dhcp /g' /boot/cmdline.txt
echo "initramfs initramfs.gz followkernel" >> /boot/config.txt
echo '>>> Setting up Dropbear options...'
mv /authorized_keys /etc/dropbear-initramfs/authorized_keys
sed -i 's/^DROPBEAR_OPTIONS.*$//g' /etc/dropbear-initramfs/config
rm /etc/dropbear-initramfs/dropbear_*_host_key
dropbearkey -t rsa -s 4096 -f /etc/dropbear-initramfs/dropbear_rsa_host_key

echo 'INITRD=Yes' >> /etc/default/raspberrypi-kernel


cat << 'XOF' | install -m 755 /dev/stdin /etc/kernel/postinst.d/ZZ-initramfs-tools
#!/bin/sh -e
version="$1"
bootopt=""

if [ -e "/boot/initrd.img-${version}" ]; then
        echo reallocating initrd
        mv "/boot/initrd.img-${version}" /boot/initramfs.gz
else
        echo not reallocating initrd
fi
XOF

echo 'crypt_sdcard /dev/mmcblk0p2 none luks' >> /etc/crypttab
sed -i 's/\#disable_overscan\=1/disable_overscan\=1/g' /boot/config.txt

sed -i 's/^PARTUUID.*$//g' /etc/fstab 
echo '/dev/mmcblk0p1  /boot           vfat    defaults          0       2'  >> /etc/fstab
echo '/dev/mapper/crypt_sdcard  /               ext4    defaults,noatime  0       1' >> /etc/fstab

if [ -L "/dev/mmcblk0p2" ]; then
	echo '>> Removing previous /dev/mmcblk0p2 Link'
	rm /dev/mmcblk0p2
fi
if [ ! -e "/dev/mmcblk0p2" ]; then
        echo '>> Creating new /dev/mmcblk0p2 Link'
	ln -s "$1" /dev/mmcblk0p2
fi
echo '----------------------------------------------------------------------------'
echo 'Common options (try yourself):'
echo '*+     for RPI 1?'
echo '*-v7+  for RPI 2/3?'
echo '*-v7l+ for RPI 4'
echo '----------------------------------------------------------------------------'
cd /lib/modules
select KERNELVER in *; do test -n "$KERNELVER" && break; echo "> Invalid Selection <"; done
EOF

echo "printf 'DROPBEAR_OPTIONS=\"%s\"\n' '" >> /tmp/rpisystem/update.sh
echo "${DROPBEAR_OPTIONS}" >> /tmp/rpisystem/update.sh
echo "' >> /etc/dropbear-initramfs/config" >> /tmp/rpisystem/update.sh

cat << 'EOF' >> /tmp/rpisystem/update.sh
echo building initramfs...
mkinitramfs -v -o /boot/initramfs.gz "${KERNELVER}"
EOF

echo -e "${BIWhite}[+] Updating target system${Color_Off}"
LANG=C chroot /tmp/rpisystem /bin/su -l -c "/update.sh ${TARGET_DEV}2"
echo
echo
echo "---------------------------------------------------------------------------"
echo "This is the raspberry system:"
echo "You can use this shell to install your rpi stuff!"
echo "Recommended things: change pi password, enable ssh, etc..."
echo "Type 'exit' command to finish the installation"
echo "---------------------------------------------------------------------------"
LANG=C chroot /tmp/rpisystem /bin/su -
rm /tmp/rpisystem/update.sh
cleanup "${TARGET_IMG}"

clear
echo
echo 
echo "ENCRYPTED INSTALLATION COMPLETED."
echo "REMOVE THE SDCARD FROM YOUR COMPUTER AND INSERT IT INTO YOUR RASPBERRY PI"
