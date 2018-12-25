# raspberrypi-ua-netinst [![Issue Count](https://codeclimate.com/github/FooDeas/raspberrypi-ua-netinst/badges/issue_count.svg)](https://codeclimate.com/github/FooDeas/raspberrypi-ua-netinst)

- [Intro](#intro)
- [Requirements](#requirements)
- [Install instructions](#install-instructions)
- [Writing the installer to the SD card](#writing-the-installer-to-the-sd-card)
- [Installing](#installing)
- [Installer customization](#installer-customization)
- [First boot](#first-boot)
- [Logging](#logging)
- [Reinstalling or replacing an existing system](#reinstalling-or-replacing-an-existing-system)
- [Disclaimer](#disclaimer)

## Intro

The minimal Raspbian unattended netinstaller for Raspberry Pi.  

This initially was a fork of [raspbian-ua-netinst](https://github.com/debian-pi/raspbian-ua-netinst). Because of extensive changes and improvements it became independent.  
Some of the main differences are:

- improved performance out of the box
- full featured kernel and bootloader from raspberrypi.org (compatible with apt)
- more installer customization options
- ability to install via onboard wireless lan
- better compatibility with accessory

This project gives [Raspbian][1] power users the ability to install a minimal base system unattended using the latest Raspbian packages, regardless when the installer was built.

The installer with the default settings configures eth0 with DHCP to get internet connectivity and completely wipes the SD card from any previous installation.

### Features

- completely unattended, you only need a working internet connection through the ethernet port or use the onboard wireless LAN (supported on model 3B, 3B+ and 0W)
- DHCP and static IP configuration (DHCP is the default)
- always installs the latest version of Raspbian
- configurable default settings
- extra configuration over HTTP possible - gives unlimited flexibility
- installation takes about **20 minutes** with fast internet from power on to sshd running
- can fit on a 512MB SD card, but 1GB is more reasonable
- default installation includes `fake-hwclock` to save the current time at shutdown
- default installation includes NTP to keep time
- `/tmp` is mounted as tmpfs to improve speed
- no clutter included, you only get the bare essential packages
- option to install root to a USB drive

## Requirements

- a Raspberry Pi (from model 1B up to 3B, 3A+, 3B+ or Zero including Zero W)
- SD card with at least 1GB, or at least 128MB for USB root install (without customization)
- ethernet or wireless LAN with a working internet connection

## Install instructions

1. Write the installer to the SD card
1. Provide unattended installation settings (optional) or follow the first boot steps later
1. Power on the Raspberry Pi and wait until the installation is done

## Writing the installer to the SD card

The installer archive contains all firmware files and the installer.

Go to [our latest release page](https://github.com/FooDeas/raspberrypi-ua-netinst/releases/latest) and download the .zip file.

Format your SD card as **FAT32** (MS-DOS on _Mac OS X_) and extract the installer files.

**Note:** If you get an error saying it can't mount `/dev/mmcblk0p1` on `/boot` then the most likely cause is that you're using exFAT instead of FAT32. Try formatting the SD card with [this tool](https://www.sdcard.org/downloads/formatter_4/).  
Further methods are described in [doc/INSTALL_ADVANCED.md](/doc/INSTALL_ADVANCED.md).

## Installing

Under normal circumstances, you can just power on your Pi and cross your fingers.

If you don't have a display attached, you can monitor the ethernet card LEDs to guess the activity status. When it finally reboots after installing everything you will see them illuminate on and off a few times when Raspbian configures on boot.

If the installation process fails, you will see **SOS** in Morse code (... --- ...) on an led.  In this case, power off the Pi and check the log on the sd card.

If you do have a display, you can follow the progress and catch any possible errors in the default configuration or your own modifications. Once a network connection has been established, the process can also be followed via telnet (port 23).

If you have a serial cable connected, installer output can be followed there, too. If 'console=tty1' at then end of the `cmdline.txt` file is removed, you have access to the console in case of problems.

## Installer customization

You can use the installer _as is_ and get a minimal system installed which you can then use and customize to your needs.

**All configuration files and folders have to be placed in `raspberrypi-ua-netinst/config` on the SD card.**  
This is the configuration directory of the installer.

### Unattended install settings

The primary way to customize the installation process is done through a file named _installer-config.txt_. Edit or create this file in the _config_ folder on the SD card.

If you want settings changed for your installation, you should **only** place that changed setting in the _installer-config.txt_ file. So if you want to have vim and aptitude installed by default, edit or create the _installer-config.txt_ file with the following contents:

```
packages=vim,aptitude
```

That's it!

Here is another example for a _installer-config.txt_ file:

```
packages=nano
firmware_packages=1

timezone=America/New_York
keyboard_layout=us
system_default_locale=en_US

username=pi
userpw=login
userperms_admin=1
usergpu=1

rootpw=raspbian
root_ssh_pwlogin=0

gpu_mem=32
```

All possible parameters and their description, are documented in [doc/INSTALL_CUSTOM.md](/doc/INSTALL_CUSTOM.md).

### Advanced customization

More advanced customization as providing files or executing own scripts is documented in [doc/INSTALL_ADVANCED.md](/doc/INSTALL_ADVANCED.md).

## First boot

The system is almost completely unconfigured on first boot. Here are some tasks you most definitely want to do on first boot.  
Note, that this manual work can be done automatically during the installation process if the appropriate options in [`installer-config.txt`](#installer-customization)) are set.

The default **root** password is **raspbian**.

- Set new root password: `passwd`
- Configure your default locale: `dpkg-reconfigure locales`
- Configure your keyboard layout: `dpkg-reconfigure keyboard-configuration`
- Configure your timezone: `dpkg-reconfigure tzdata`

Optional:  
Create a swap file with `dd if=/dev/zero of=/swap bs=1M count=512 && chmod 600 /swap && mkswap /swap` (example is 512MB) and enable it on boot by appending `/swap none swap sw 0 0` to `/etc/fstab`.  

## Logging

The output of the installation process is logged to file.  
When the installation completes successfully, the logfile is placed in `/var/log/raspberrypi-ua-netinst.log` on the installed system.  
When an error occurs during install, the logfile is placed in the `raspberrypi-ua-netinst` folder and is named `error-\<datetimestamp\>.log`

## Reinstalling or replacing an existing system

If you want to reinstall with the same settings you did your first install you can just move the original _config.txt_ back and reboot.

```
mv /boot/raspberrypi-ua-netinst/reinstall/config.txt /boot/config.txt
reboot
```

**Remember to backup all your data and original `config.txt` before doing this!**

## Disclaimer

We take no responsibility for ANY data loss. You will be reflashing your SD card anyway so it should be very clear to you what you are doing and will lose all your data on the card. Same goes for reinstallation.

See LICENSE for license information.

[1]: http://www.raspbian.org/ "Raspbian"
