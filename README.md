# RPI3/4 Headless Installer
  
Author: Aarón G. Mizrachi Pérez (unmanarc) <aaron@unmanarc.com>  
License: MIT
  
***

## About

This set of scripts enable you to install **ubuntu** or **raspios** images on your raspberry.

## Advantages

- LUKS rootfs encryption
- SSH Remote Unlock (provided by dropbear)
- Headless boot (you won't require a monitor to deploy your rpi servers)
- Ability to Pre-install / deploy software/configuration inside your encrypted SDCard from your computer (before starting with the rpi hardware)
- The encryption takes place during the installation, no need to use the old fashion way (like writing the unencrypted base system first into the SDCard, making an image of it, and reencrypting...)
- You will be able to unlock the device using a remote SSH
- Tested on RPI4 and RPI3

### CRYPTO-SPECS

- Encryption: AES-256-XTS
- Hash: SHA-256

### Pre-requisites

- A computer with Linux (tested with ubuntu 18.04/20.04 x86_64 and Fedora >=31)
- An SD Card, I recommend at least 16Gb, with the U3 logo, from a well known provider.

***

## How to...
  
First, download the repo

```
git clone https://github.com/unmanarc/rpi-headless-crypto-installer
```

Then, go into the dir and chmod the scripts

```
cd rpi-headless-crypto-installer
chmod +x *.sh
```

Now... Download your OS, eg.

- raspbian image (eg. 2019-09-26-raspbian-buster-lite.img)
- ubuntu server image (ubuntu-20.04-preinstalled-server-arm64+raspi.img)
  
**Note: if it's compressed as zip or tar.gz, unzip/untar, we need the .img, not the zip.**

Then, use the script as root:

```
sudo ./install_encrypted_raspbian.sh 2019-09-26-raspbian-buster-lite.img /dev/sdx /home/youruser/.ssh/id_rsa.pub
```
or:
```
sudo ./install_encrypted_ubuntu.sh ubuntu-20.04-preinstalled-server-arm64+raspi.img /dev/sdx /home/youruser/.ssh/id_rsa.pub
```

Then you should confirm with "YES" if the image comes from a trustworthy place, and then if the destionation is the proper SD Card. 
  
**BE CAREFUL, this will WIPE OUT your selected device, if you have some valuable information there, please make a backup of your pc and sdcard before doing anything with this script.**

**BE CAREFUL, if you mistake with the device (eg. using /dev/sda instead /dev/sdx), the target will also be wiped out, and there is no way to roll back.**

### Starting/Unlocking

1. Plug the SD Card into the RPI
2. Plug the Network cable into the RPI (DHCP Required)
3. Plug the power USB cord into the RPI
4. Wait for one or two minutes while the RPI gets the IP/DHCP address
5. You can discover the addres using the following alternatives:
   1. Open your router/wifi and check the DHCP Clients table
   2. for one RPI connected, supposing your network is 192.168.0.0/24 use `nmap -n -sP 192.168.0.0/24`, and then check for the `(Raspberry Pi Trading)` signature
   3. Another option is to scan the 5022 port with nmap `nmap -n -p 5022 192.168.0.0/24`
   4. The last option is to use a monitor, the ip address will show on screen
6. Once you know the rpi ip address, eg. `192.168.0.124`, go with the SSH client

```
ssh -p 5022 -i /home/youruser/.ssh/id_rsa.pub 192.168.0.124
```

**Note:** replace the `192.168.0.124` using your DHCP obtained IP address.

**Note:** if you want to have an *Static IP Address*, you can:

1. modify the script (search the `ip=:::::eth0:dhcp`)
2. or assign an static IP for your MAC in your router DHCP Server**

### Troubleshooting Raspbian/RaspiOS with RPI Versions

If the initrd unlock process does not accept your password (or even your keyboard), you may have choosen a bad kernel modules. Remember: v7l+ is for RPI4, and v7+ for RPI3, then the kernel itself is selected by the bootloader, however the initrd modules are selected by you.

## TODO

- Remote decryption over WiFi (eg. hostapd during initrd)

