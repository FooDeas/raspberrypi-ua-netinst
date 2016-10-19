# `installer-config.txt` options

- [Package](#package)
- [Device / peripheral](#device--peripheral)
- [Root](#root)
- [User](#user)
- [Network](#network)
- [Localization](#localization)
- [Partitioning / Filesystem](#partitioning--filesystem)
- [Advanced](#advanced)

## Package
| Parameter         | Default | Options                   | Description                                                                                          |
|-------------------|---------|---------------------------|------------------------------------------------------------------------------------------------------|
| `preset` | `server` | `base`/  `minimal`/  `server` | The current packages that are installed by default are listed below. |
| `packages` |  |  | Install this additional packages (comma separated and quoted). (e.g. "pi-bluetooth,cifs-utils,curl") |
| `firmware_packages` |  | `0` | `0`/`1` | Set to "1" to install common firmware packages (Atheros, Broadcom, Libertas, Ralink and Realtek) |
| `mirror` | `http://mirrordirector.raspbian.org/raspbian/` |  |  |
| `release` | `jessie` |  |  |

### Description: Presets
| Preset | Packages |
|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `base` | _\<essential\>,apt,cpufrequtils,kmod,raspbian-archive-keyring_ |
| `minimal` | _\<base\>,fake-hwclock,ifupdown,net-tools,ntp,openssh-server,dosfstools,raspberrypi-sys-mods_ |
| `server` | _\<minimal\>,vim-tiny,iputils-ping,wget,ca-certificates,rsyslog,cron,dialog,locales,less,man-db,bash-completion,console-setup,apt-utils,libraspberrypi-bin,raspi-copies-and-fills_ |

## Device / peripheral
| Parameter          | Default | Options | Description                                                                                                                                                                                                                                      |
|--------------------|---------|---------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `gpu_mem` |  |  | Specifies the amount of RAM in MB that should be reserved for the GPU. To allow the VideoCore GPU kernel driver to be loaded correctly, you should use at least "32". If not defined, the bootloader sets it to 64MB. The minimum value is "16". |
| `spi_enable` | `0` | `0`/`1` | Set to "1" to enable the SPI interface. |
| `i2c_enable` | `0` | `0`/`1` | Set to "1" to enable the I²C (I2C) interface. |
| `sound_enable` | `0` | `0`/`1` | Set to "1" to enable the onboard audio. |
| `camera_enable` | `0` | `0`/`1` | Set to "1" to enable the camera module. This sets all needed parameters in config.txt. |
| `camera_disable_led` | `0` | `0`/`1` | Disables the camera led. The option `camera_enable=1` has to be set to take effect. |

## Root
| Parameter       | Default | Options | Description                                                                                          |
|-----------------|---------|---------|------------------------------------------------------------------------------------------------------|
| `rootpw` | raspbian |  | Sets password for root. To disable root, also set root_ssh_pubkey empty. |
| `root_ssh_pubkey` |  |  | Sets public SSH key for root login. The public SSH key must be on a single line, enclosed in quotes. |
| `root_ssh_allow` | `1` | `0`/`1` | Set to 0 to disable ssh password login for root. |

## User
| Parameter       | Default | Options | Description                                                                                                                                                          |
|-----------------|---------|---------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `username` |  |  | Username of the user to create |
| `userpw` |  |  | Password to use for created user |
| `usergpio` |  | `0`/`1` | Set to 1 to give created user permissions to access GPIO pins. A new system group 'gpio' will be created automatically. |
| `usergpu` |  | `0`/`1` | Set to 1 to give created user GPU access permissions (e.g. to run vcgencmd without using sudo). |
| `usergroups` |  |  | Add created user to this additional groups (comma separated and quoted). Non-existent groups will be created. (e.g. 'usergroups=family,friends') |
| `usersysgroups` |  |  | Add created user to this additional groups (comma separated and quoted). Non-existent groups will be created as system groups. (e.g. 'usersysgroups=video,www-data') |
| `user_ssh_pubkey` |  |  | public SSH key for created user; the public SSH key must be on a single line, enclosed in quotes |
| `user_is_admin` |  | `0`/`1` | set to 1 to install sudo and make the user a sudo user |

## Network
| Parameter      | Default | Options | Description                                                                                                                                               |
|----------------|---------|---------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `hostname` | `pi` |  |  |
| `domainname` |  |  |  |
| `ifname` | `eth0` |  | Change to 'wlan0' to use onboard WiFi. Use the 'wlan_*' options below or provide a 'wpa_supplicant.conf' with WiFi login data in the directory `/config`. |
| `wlan_ssid` |  |  | Sets SSID for WiFi authentication if no 'wpa_supplicant.conf' is provided. |
| `wlan_psk` |  |  | Sets PSK for Wifi authentication if no 'wpa_supplicant.conf' is provided. |
| `ip_addr` | `dhcp` |  |  |
| `ip_netmask` | `0.0.0.0` |  |  |
| `ip_broadcast` | `0.0.0.0` |  |  |
| `ip_gateway` | `0.0.0.0` |  |  |
| `ip_nameservers` |  |  |  |

## Localization
| Parameter             | Default | Options | Description                                                                                                                                                      |
|-----------------------|---------|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `timezone` | `Etc/UTC` | [ref: doc/timezone.txt](/doc/timezone.txt) | Set to desired timezone (e.g. Europe/Ljubljana) |
| `keyboard_layout` | `us` | [ref: doc/keyboard_layout.txt](/doc/keyboard_layout.txt) | Set default keyboard layout. (e.g. "de") |
| `locales` |  | [ref: doc/locales.txt](/doc/locales.txt) | Generate locales from this list (comma separated and quoted). UTF-8 is chosen preferentially if no encoding is specified. (e.g. "en_US.UTF-8,nl_NL,sl_SI.UTF-8") |
| `system_default_locale` |  | [ref: doc/locales.txt](/doc/locales.txt) | Set default system locale (using the LANG environment variable). UTF-8 is chosen preferentially if no encoding is specified. (e.g. "nl_NL" or "sl_SI.UTF-8") |

## Partitioning / Filesystem
| Parameter         | Default | Options               | Description                                                                                                                                                                                                                                     |
|-------------------|---------|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `usbroot` |  |  | Set to 1 to install to first USB disk. |
| `rootfstype` | f2fs | `ext4`/  `f2fs`/  `btrfs` | Sets the file system of the root partition. |
| `boot_volume_label` |  |  | Sets the volume name of the boot partition. The volume name can be up to 11 characters long. The label is used by most OSes (Windows, Mac OSX and Linux) to identify the SD-card on the desktop and can be useful when using multiple SD-cards. |
| `bootsize` | `+128M` |  | /boot partition size in megabytes, provide it in the form '+<number>M' (without quotes) |
| `bootoffset` | `8192` |  | position in sectors where the boot partition should start. Valid values are > 2048. a bootoffset of 8192 is equal to 4MB and that should make for proper alignment |

## Advanced
| Parameter | Default | Options | Description |
|------------------------------|---------|----------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `quiet_boot` | `0` | `0`/`1` | Disables most log messages on boot. |
| `cmdline` | `"dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 elevator=deadline fsck.repair=yes"` |  |  |
| `rootfs_install_mount_options` |  |  |  |
| `rootfs_mount_options` |  |  |  |
| `final_action` | `reboot` | `poweroff`/  `halt`/  `reboot` | Action at the end of install. |
| `hwrng_support` | `1` | `0`/`1` | Install support for the ARM hardware random number generator. The default is enabled (1) on all presets. Users requiring a `base` install are advised that `hwrng_support=0` must be added in `installer-config.txt` if HWRNG support is undesirable. |
| `enable_watchdog` | `0` | `0`/`1` | loads up the hardware watchdog module and configures systemd to use it. Set to "1" to enable this functionality. |
| `cdebootstrap_cmdline` |  |  |  |
| `rootfs_mkfs_options` |  |  |  |
| `rootsize` |  |  | / partition size in megabytes, provide it in the form '+<number>M' (without quotes), leave empty to use all free space |
| `timeserver` | `time.nist.gov` |  |  |
| `timeserver_http` |  |  | URL that returns the time in the format: YYYY-MM-DD HH:MM:SS. |
| `disable_predictable_nin` | `1` | `0`/`1` | Disable Predictable Network Interface Names. Set to 0 if you want to use predictable network interface names, which means if you use the same SD card on a different RPi board, your network device might be named differently. This will result in the board having no network connectivity. |
| `drivers_to_load` |  |  | Loads additional kernel modules at installation (comma separated and quoted). |
| `online_config` |  |  | URL to extra config that will be executed after installer-config.txt |
