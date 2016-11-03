# Advanced installation
Less important information are listed here. They are structured just as the main readme.

## Writing the installer to the SD card

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

## Installer customization

### Bring your own files
If you want to provide files to the installed system during the installation, place them in the `files/root` directory. The folder `root` is the root-point. It must have the same structure as inside the installed system. So, a file that you place on the SD card in `root/etc/wpa_supplicant/wpa_supplicant.conf` will end up on the installed system as `/etc/wpa_supplicant/wpa_supplicant.conf`.
Each file or directory that you wish to place on the target system must also be listed in a configuration file in the directory `files`. This allows you to specify the owner (and group) and the permissions of the file. An example file is provided with the installer (see `raspberrypi-ua-netinst/config/files/custom_files.txt` for more information). ONLY files listed there are copied over to the installed system.  
Please be aware that some restrictions may apply to the sum of the file sizes. If you wish to supply large files in this manner you may need to adjust the value of the `bootsize` parameter.

### Post installer script
You can provide a _post-install.txt_ file that is executed at the very end of the installation process and you can use it to tweak and finalize your automatic installation.

### Custom installer script
It is possible to replace the installer script completely, without rebuilding the installer image. To do this, place a custom `rcS` file in the `raspberrypi-ua-netinst` directory of your SD card. The installer script will check this location and run this script instead of itself. Take great care when doing this, as it is intended to be used for development purposes.
