# Encrypted Raspbian Installer
  
Author: Aarón Mizrachi (unmanarc) <aaron@unmanarc.com>  
License: MIT
  
## How to use this...
  
Download your raspbian image (eg. 2019-09-26-raspbian-buster-lite.img), 
  
Then, use the script:

./install_encrypted_raspbian.sh 2019-09-26-raspbian-buster-lite.img /dev/sdx /home/youruser/.ssh/id_rsa.pub
  
Then you should confirm with "YES" if the image comes from a trustworthy place, and then if the destionation is the proper SD Card. 
  
BE CAREFUL, this will WIPE OUT your selected device, if you have some valuable information there, please make a backup of your pc and sdcard before doing anything with this script.
BE CAREFUL, if you mistake with the device (eg. using /dev/sda instead /dev/sdx), the target will also be wiped out, and there is no way to roll back.

## Some advantages

- The encryption takes place during the installation itself, there is no need to install the unencrypted base system first, make an image, and reencrypt...
- You will be able to unlock the device using SSH (ssh -p 5022 -i /home/youruser/.ssh/id_rsa.pub a.b.c.d)
- Tested on RPI4 and RPI3
- You can pre-install / deploy any software inside your encrypted system before even you insert the sdcard into the raspberry for the first time.

## Troubleshooting

If the initrd unlock process does not accept your password (or even your keyboard), you may have choosen a bad kernel modules. Remember: v7l+ is for RPI4, and v7+ for RPI3, then the kernel itself is selected by the bootloader, however the initrd modules are selected by you.

## TODO

- Remote decryption over WiFi (eg. hostapd during initrd)
- Test with other images (eg. ubuntu)
