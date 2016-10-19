# raspberrypi-ua-netinst

- [Fork Modifications](#modifications)
- [Intro](#intro)
- [Features](#features)
- [Requirements](#requirements)
- [Writing the installer to the SD card](#writing-the-installer-to-the-sd-card)
- [Installing](#installing)
- [Installer customization](#installer-customization)
- [Logging](#logging)
- [First boot](#first-boot)
- [Reinstalling or replacing an existing system](#reinstalling-or-replacing-an-existing-system)
- [Disclaimer](#disclaimer)

## Fork Modifications

This initially was a fork of [raspbian-ua-netinst](https://github.com/debian-pi/raspbian-ua-netinst). Because of extensive changes and improvements it became independent.  
Some of the main differences are:
 - full featured kernel and bootloader from raspberrypi.org (compatible with apt)
 - more installer customization options
 - ability to install via onboard wireless lan
 - better compatibility with accessory
 - improved performance out of the box

## Intro

The minimal Raspbian unattended netinstaller for Raspberry Pi.  

This project provides [Raspbian][1] power users the possibility to install a minimal base system unattended using latest Raspbian packages regardless when the installer was built.

The installer with default settings configures eth0 with DHCP to get internet connectivity and completely wipes the SD card from any previous installation.

## Features
 - completely unattended, you only need a working internet connection through the ethernet port or use the onboard wireless lan (supported on model 3B)
 - DHCP and static ip configuration (DHCP is the default)
 - always installs the latest version of Raspbian
 - configurable default settings
 - extra configuration over HTTP possible - gives unlimited flexibility
 - installation takes about **20 minutes** with fast internet from power on to sshd running
 - can fit on a 512MB SD card, but 1GB is more reasonable
 - default install includes `fake-hwclock` to save time on shutdown
 - default install includes NTP to keep time
 - `/tmp` is mounted as tmpfs to improve speed
 - no clutter included, you only get the bare essential packages
 - option to install root to USB drive

## Requirements
 - a Raspberry Pi from model 1B up to 3B or Zero
 - SD card of at least 1GB or at least 128MB for USB root install (without customization)
 - working ethernet or wireless lan with internet connectivity

## Writing the installer to the SD card
### Obtaining installer files
Installer archive contains all firmware files and the installer.

Go to [our latest release page](https://github.com/FooDeas/raspberrypi-ua-netinst/releases/latest) and download the .zip file.

Format your SD card as **FAT32** (MS-DOS on _Mac OS X_) and extract the installer files.

**Note:** If you get an error saying it can't mount `/dev/mmcblk0p1` on `/boot` then the most likely cause is that you're using exFAT instead of FAT32. Try formatting the SD card with [this tool](https://www.sdcard.org/downloads/formatter_4/). 

### Alternative method for Mac
Prebuilt image is bzip2 compressed and contains the same files as the `.zip`.

Go to [the latest release page](https://github.com/FooDeas/raspberrypi-ua-netinst/releases/latest) and download the `.img.bz2` file.  
Extract the `.img` file from the archive with `bunzip2 raspberrypi-ua-netinst-<latest-version-number>.img.bz2`.  
Find the _/dev/diskX_ device you want to write to using `diskutil list`. It will probably be 1 or 2.  

To flash your SD card on Mac:

    diskutil unmountDisk /dev/diskX
    sudo dd bs=1m if=/path/to/raspberrypi-ua-netinst-<latest-version-number>.img of=/dev/rdiskX
    diskutil eject /dev/diskX

_Note the **r** in the of=/dev/rdiskX part on the dd line which should speed up writing the image considerably._

### Alternative method for Linux
Prebuilt image is xz compressed and contains the same files as the `.zip`.

Go to [our latest release page](https://github.com/FooDeas/raspberrypi-ua-netinst/releases/latest) and download the `.img.xz` file.  
To flash your SD card on Linux:

    xzcat /path/to/raspberrypi-ua-netinst-<latest-version-number>.img.xz > /dev/sdX

Replace _/dev/sdX_ with the real path to your SD card.

## Installing
In normal circumstances, you can just power on your Pi and cross your fingers.

If you don't have a display attached you can monitor the ethernet card LEDs to guess the activity status. When it finally reboots after installing everything you will see them illuminate on and off a few times when Raspbian configures on boot.

If you do have a display, you can follow the progress and catch any possible errors in the default configuration or your own modifications.  
If you have a serial cable connected, installer ouput can be followed there, too. If 'console=tty1' at then end of the `cmdline.txt` file is removed, you have access to the console in case of problems.

## Installer customization
You can use the installer _as is_ and get a minimal system installed which you can then use and customize to your needs.

But you can also customize the installation process and the primary way to do that is through a file named _installer-config.txt_. When you've written the installer to a SD card, you'll see a file named _cmdline.txt_ and you create the _installer-config.txt_ file alongside that file.
If you want settings changed for your installation, you should **only** place that changed setting in the _installer-config.txt_ file. So if you want to have vim and aptitude installed by default, create a _installer-config.txt_ file with the following contents:
```
packages=vim,aptitude
```
That's it!

Here is another example for a _installer-config.txt_ file:

```
packages=nano,logrotate
firmware_packages=1

timezone=America/New_York
keyboard_layout=us
system_default_locale=en_US

username=pi
userpw=login
user_is_admin=1
usergpu=1

rootpw=raspbian
root_ssh_allow=0

gpu_mem=32
```

All possible parameters and their description, are documented in [doc/INSTALL_CUSTOM.md](/doc/INSTALL_CUSTOM.md).

The _installer-config.txt_ is read in at the beginning of the installation process, shortly followed by the file pointed to with `online_config`, if specified.
There is also another configuration file you can provide, _post&#8209;install.txt_, and you place that in the same directory as _installer-config.txt_.
The _post&#8209;install.txt_ is executed at the very end of the installation process and you can use it to tweak and finalize your automatic installation.

### Bring your own files
You can have the installer place your custom configuration files (or any other file you wish to add) on the installed system during the installation. For this, you need to provide the necessary files in the `/config/files/` directory of your SD card (you may need to create this directory if it doesn't exist). The `/config/files/` directory is the root-point. It must have the same structure as inside the installed system. So, a file that you place on the SD card in `/config/files/etc/wpa_supplicant/wpa_supplicant.conf` will end up on the installed system as `/etc/wpa_supplicant/wpa_supplicant.conf`.
Each file or directory that you wish to place on the target system must also be listed in a configuration file in the directory `/config` on your SD card. This allows you to specify the owner (and group) and the permissions of the file. An example file is provided with the installer (see `/config/my-files.list` for more information). ONLY files listed there are copied over to the installed system.
To have the installer actually copy the files to the target system, add the following command at an appropriate point in your `post-install.txt` file:
```
install_files my-files.list
```
where `my-files.list` is the name of the file containing the list of files.
If needed, you can call `install_files` multiple times with different list files.  
Please be aware that some restrictions may apply to the sum of the file sizes. If you wish to supply large files in this manner you may need to adjust the value of the `bootsize` parameter.

### Custom installer script
It is possible to replace the installer script completely, without rebuilding the installer image. To do this, place a custom `rcS` file in the config directory of your SD card. The installer script will check this location and run this script instead of itself. Take great care when doing this, as it is intended to be used for development purposes.

Should you still choose to go this route, please use the original [`rcS`](/scripts/etc/init.d/rcS) file as a starting point.

## Logging
The output of the installation process is now also logged to file.  
When the installation completes successfully, the logfile is moved to `/var/log/raspberrypi-ua-netinst.log` on the installed system.  
When an error occurs during install, the logfile is moved to the sd card, which gets normally mounted on `/boot/` and will be named `raspberrypi-ua-netinst-\<datetimestamp\>.log`

## First boot
The system is almost completely unconfigured on first boot. Here are some tasks you most definitely want to do on first boot.

The default **root** password is **raspbian**.

> Set new root password: `passwd`
> Configure your default locale: `dpkg-reconfigure locales`
> Configure your keyboard layout: `dpkg-reconfigure keyboard-configuration`
> Configure your timezone: `dpkg-reconfigure tzdata`

This manual work can be done automatically by using the appropriate options in [`installer-config.txt`](#installer-customization)).

> Optional: Create a swap file with `fallocate -l 512M /swap && mkswap /swap && chmod 600 /swap` (example is 512MB) and enable it on boot by appending `/swap none swap sw 0 0` to `/etc/fstab`.  

## Reinstalling or replacing an existing system
If you want to reinstall with the same settings you did your first install you can just move the original _config.txt_ back and reboot.

    mv /boot/config-reinstall.txt /boot/config.txt
    reboot

**Remember to backup all your data and original `config.txt` before doing this!**

## Disclaimer
We take no responsibility for ANY data loss. You will be reflashing your SD card anyway so it should be very clear to you what you are doing and will lose all your data on the card. Same goes for reinstallation.

See LICENSE for license information.

  [1]: http://www.raspbian.org/ "Raspbian"
