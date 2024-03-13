# `installer-config.txt` options

- [Package](#package)
- [Device / peripheral](#device--peripheral)
- [SSH](#ssh)
- [User](#user)
- [Network](#network)
- [Localization](#localization)
- [Graphics / GPU](#graphics--gpu)
- [Partitioning / Filesystem](#partitioning--filesystem)
- [Advanced](#advanced)

## Package

| Parameter | Default | Options | Description |
|---------------------|--------------------------------------------------|-------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `preset` | `server` | `base`/  `minimal`/  `server` | The current packages that are installed by default are listed below. |
| `packages` |  |  | Install these additional packages (comma separated and quoted). (e.g. "pi-bluetooth,cifs-utils,curl") |
| `firmware_packages` | `0` | `0`/`1` | Set to "1" to install common firmware packages (Atheros, Broadcom, Libertas, Ralink and Realtek). |
| `mirror` | `http:// mirrordirector.raspbian.org/ raspbian/` or `http:// deb.debian.org/ debian/` |  | default value depends on arch |
| `mirror_cache` |  |  | Set address and port for HTTP apt-cacher or apt-cacher-ng (e.g. "192.168.0.1:3142"). If set, the cacher will be used to cache packages during installation downloaded from the repository set in `mirror` as well as "http://archive.raspberrypi.org/debian". |
| `release` | `bullseye` |  | Raspbian release name |
| `arch` | `armhf` |  | Raspbian architecture: "armhf" = 32-bit (all Raspberry models), "arm64" = 64-bit (only for Model 3 and up, Zero 2) |

### Description: Presets

#### Default configuration (when `use_systemd_services` is unset or set to `0`)

| Preset | Packages |
|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `base` | _\<essential\>,apt,gnupg,kmod_ |
| `minimal` | _\<base\>,cpufrequtils,fake-hwclock,ifupdown,net-tools,ntpsec,openssh-server,dosfstools,raspberrypi-sys-mods_ |
| `server` | _\<minimal\>,systemd-sysv,vim-tiny,iputils-ping,wget,ca-certificates,rsyslog,cron,dialog,locales,tzdata,less,man-db,logrotate,bash-completion,console-setup,apt-utils,libraspberrypi-bin,raspi-copies-and-fills (raspi-copies-and-fills is not available on arm64)_ |

Note that if the networking configuration is set to use DHCP, `isc-dhcp-client` will also be installed.

#### Advanced configuration (when `use_systemd_services` is set to `1`)

| Preset | Packages |
|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `base` | _\<essential\>,apt,kmod_ |
| `minimal` | _\<base\>,cpufrequtils,iproute2,systemd-resolved,systemd-timesyncd,openssh-server,dosfstools,raspberrypi-sys-mods_ |
| `server` | _\<minimal\>,systemd-sysv,vim-tiny,iputils-ping,wget,ca-certificates,rsyslog,cron,dialog,locales,tzdata,less,man-db,logrotate,bash-completion,console-setup,apt-utils,libraspberrypi-bin,raspi-copies-and-fills (raspi-copies-and-fills is not available on arm64)_ |

Note that if the networking configuration is set to use DHCP, no additional packages will be installed as `systemd-networkd` provides DHCP client support.

## Device / peripheral

| Parameter | Default | Options | Description |
|----------------------|---------|----------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `spi_enable` | `0` | `0`/`1` | Set to "1" to enable the SPI interface. |
| `i2c_enable` | `0` | `0`/`1` | Set to "1" to enable the I²C (I2C) interface. |
| `i2c_baudrate` |  |  | Specifies the I²C baudrate in bit/s. If not defined, the bootloader sets it to 100000 bit/s. The option `i2c_enable=1` has to be set to take effect. |
| `sound_enable` | `0` | `0`/`1` | Set to "1" to enable the onboard audio. |
| `sound_usb_enable` | `0` | `0`/`1` | Set to "1" to enable the USB audio. This will install the packages `alsa-utils`, `jackd`, `oss-compat` and `pulseaudio`. |
| `sound_usb_first` | `0` | `0`/`1` | Set to "1" to define USB audio as default if onboard audio is also enabled. The options `sound_enable=1` and `sound_usb_enable=1` have to be set to take effect. |
| `camera_enable` | `0` | `0`/`1` | Set to "1" to enable the camera module. This enables all camera-related parameters in config.txt. |
| `camera_disable_led` | `0` | `0`/`1` | Disables the camera LED. The option `camera_enable=1` has to be set to take effect. |
| `rtc` |  | `ds1307`/  `ds1339`/  `ds3231`/  `mcp7940x`/  `mcp7941x`/  `pcf2127`/  `pcf8523`/  `pcf8563`/  `abx80x` | Select an RTC if it is connected via I²C. |
| `dt_overlays` |  |  | Enables additional device tree overlays (comma separated and quoted). (e.g. 'dt_overlays="hifiberry-dac,lirc-rpi"') |

## SSH

| Parameter | Default | Options | Description |
|--------------------|---------|---------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `user_ssh_pubkey` |  |  | Public SSH key for created user; the public SSH key must be on a single line, enclosed in quotes. Alternatively, a file can be specified which is located in the `config/files` directory. |
| `root_ssh_pubkey` |  |  | Sets public SSH key for root login. The public SSH key must be on a single line, enclosed in quotes. Alternatively, a file can be specified which is located in the `config/files` directory. |
| `root_ssh_pwlogin` | `1` | `0`/`1` | Set to 0 to disable ssh password login for root. |
| `ssh_pwlogin` |  | `0`/`1` | Set to 0 to disable ssh password login completely. |

## User

| Parameter | Default | Options | Description |
|-------------------|------------|---------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `username` |  |  | Username of the user to create |
| `userpw` |  |  | Password to use for created user |
| `usergpio` |  | `0`/`1` | Set to "1" to give created user permissions to access GPIO pins. A new system group 'gpio' will be created automatically. |
| `usergpu` |  | `0`/`1` | Set to "1" to give created user GPU access permissions (e.g. to run vcgencmd without using sudo). |
| `usergroups` |  |  | Add created user to this additional groups (comma separated and quoted). Non-existent groups will be created. (e.g. 'usergroups="family,friends"') |
| `usersysgroups` |  |  | Add created user to this additional groups (comma separated and quoted). Non-existent groups will be created as system groups. (e.g. 'usersysgroups="video,www-data"') |
| `userperms_admin` | `0` | `0`/`1` | Set to "1" to install sudo and make the user a sudo user. |
| `userperms_sound` | `0` | `0`/`1` | Set to "1" to add the user to the group 'audio'. This system group will be created automatically. |
| `rootpw` | `raspbian` |  | Sets password for root. To disable root completely, also set root_ssh_pubkey empty. |

## Network

| Parameter | Default | Options | Description |
|------------------|-----------|----------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| `hostname` | `pi` |  | Name of device on the network |
| `domainname` |  |  |  |
| `ifname` | `eth0` |  | Change to 'wlan0' to use onboard WiFi. Use the 'wlan_*' options below or provide a 'wpa_supplicant.conf' with WiFi login data in the directory `config`. |
| `wlan_country` |  | [ref: doc/wlan_country.txt](/doc/wlan_country.txt) | Sets the country code for the WiFi interface. |
| `wlan_ssid` |  |  | Sets SSID for Wifi authentication if no 'wpa_supplicant.conf' is provided. |
| `wlan_psk` |  |  | Sets clear text PSK (WiFi password) for Wifi authentication if no 'wpa_supplicant.conf' is provided. The PSK will be converted to the respective encrypted variant. |
| `wlan_psk_encrypted` |  |  | Sets encrypted PSK for Wifi authentication if no 'wpa_supplicant.conf' is provided. This value is not needed if `wlan_psk` is set. It overrides `wlan_psk` if both are set. |
| `ip_addr` | `dhcp` |  | Use "dhcp" to let the network DHCP server dynamically assign an IP-address or specify a static IP-address (e.g. '192.168.2.50'). |
| `ip_netmask` |  |  | Network mask (e.g. '255.255.255.0') |
| `ip_gateway` |  |  | Gateway address (e.g. '192.168.2.1') |
| `ip_nameservers` |  |  | DNS nameservers (e.g. '8.8.8.8') |
| `ip_ipv6` | `1` | `0`/`1` | Set to "0" to disable IPv6. |

## Localization

| Parameter | Default | Options | Description |
|-------------------------|-----------|----------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `timezone` | `Etc/UTC` | [ref: doc/timezone.txt](/doc/timezone.txt) | Set to desired timezone (e.g. Europe/Ljubljana) |
| `keyboard_layout` | `us` | [ref: doc/keyboard_layout.txt](/doc/keyboard_layout.txt) | Set default keyboard layout. (e.g. "de") |
| `locales` |  | [ref: doc/locales.txt](/doc/locales.txt) | Generate locales from this list (comma separated and quoted). UTF-8 is chosen preferentially if no encoding is specified. (e.g. 'locales="en_US.UTF-8,nl_NL,sl_SI.UTF-8"') |
| `system_default_locale` |  | [ref: doc/locales.txt](/doc/locales.txt) | Set default system locale (using the LANG environment variable). UTF-8 is chosen preferentially if no encoding is specified. (e.g. "nl_NL" or "sl_SI.UTF-8") |

## Graphics / GPU

| Parameter | Default | Options | Description |
|-------------------------|------------|--------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `gpu_mem` |  |  | Specifies the amount of RAM in MB that should be reserved for the GPU. To allow the VideoCore GPU kernel driver to be loaded correctly, you should use at least "32". If not defined, the bootloader sets it to 64MB. The minimum value is "16". |
| `console_blank` |  |  | Sets console blanking timeout (screensaver) in seconds. Default kernel setting is 10 minutes (`600`). The value `0` disables the blanking completely. |
| `hdmi_type` |  | `tv`/  `monitor` | Forces HDMI mode and disables automatic display identification. Choose between TV or monitor  mode and specify the resolution with the options below. If not defined, the automatic display setting is used to determine the information sent by the display. |
| `hdmi_tv_res` | `1080p` | `720p`/  `1080i`/  `1080p` | Specifies the display resolution if `hdmi_type` is set to TV mode. |
| `hdmi_monitor_res` | `1024x768` | `640x480`/  `800x600`/  `1024x768`/  `1280x1024` | Specifies the display resolution if `hdmi_type` is set to monitor mode. |
| `hdmi_disable_overscan` | `0` | `0`/`1` | Set to "1" to disable overscan. |
| `hdmi_system_only` | `0` | `0`/`1` | Set to "1" to ignore HDMI settings during installation and apply these settings only to the system. |

## Partitioning / Filesystem

| Parameter | Default | Options | Description |
|---------------------|---------|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `usbroot` | `0` | `0`/`1` | Set to "1" to install to first USB disk. |
| `usbboot` | `0` | `0`/`1` | Set to "1" to boot from first USB disk. This is usually used with 'usbroot=1' and works with model 3 (BCM2837) only. If this is used for the first time, it has to be done from SD-card and the system will shut down after success. Then the SD-card has to be removed before rebooting. |
| `rootfstype` | `f2fs` | `ext4`/  `f2fs`/  `btrfs` | Sets the file system of the root partition. |
| `boot_volume_label` |  |  | Sets the volume name of the boot partition. The volume name can be up to 11 characters long. The label is used by most OSes (Windows, Mac OSX and Linux) to identify the SD-card on the desktop and can be useful when using multiple SD-cards. |
| `root_volume_label` |  |  | Sets the volume name of the root partition. The volume name can be up to 16 characters long. |
| `bootsize` | `+128M` |  | /boot partition size in megabytes, provide it in the form '+\<number\>M' (without quotes) |
| `bootoffset` | `8192` |  | position in sectors where the boot partition should start. Valid values are > 2048. a bootoffset of 8192 is equal to 4MB and that should make for proper alignment |

## Advanced

| Parameter | Default | Options | Description |
|--------------------------------|------------------------------------------------------------------------------------------------|--------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `quiet_boot` | `0` | `0`/`1` | Disables most log messages on boot. |
| `disable_raspberries` | `0` | `0`/`1` | Disables the raspberry logos. |
| `disable_splash` | `0` | `0`/`1` | Disables the rainbow splash screen on boot. |
| `cleanup` | `0` | `0`/`1` | Remove installer files after success. To also remove log files, note the option below. |
| `cleanup_logfiles` | `0` | `0`/`1` | Removes installer log files after success. |
| `cmdline` | `"console=serial0,115200 console=tty1 fsck.repair=yes"` |  |  |
| `final_action` | `reboot` | `reboot`/  `poweroff`/  `halt`/  `console` | Action at the end of install. |
| `installer_telnet` | `listen` | `none`/`connect`/`listen` | Connect to, or listen for, a telnet connection to send installer console output. |
| `installer_telnet_host` | | | Host name or address to use when `installer_telnet` is set to `connect`. |
| `installer_telnet_port` | '9923' |  | Port number to use when `installer_telnet` is set to `connect`. |
| `installer_retries` | `3` |  | Number of retries if installation fails. |
| `installer_networktimeout` | `15` |  | Timeout in seconds for network interface initialization. |
| `installer_pkg_updateretries` | `3` |  | Number of retries if package update fails. |
| `installer_pkg_downloadretries` | `5` |  | Number of retries if package download fails. |
| `hwrng_support` | `1` | `0`/`1` | Install support for the ARM hardware random number generator. The default is enabled (1) on all presets. Users requiring a `base` install are advised that `hwrng_support=0` must be added in `installer-config.txt` if HWRNG support is undesirable. |
| `watchdog_enable` | `0` | `0`/`1` | Set to "1" to enable and use the hardware watchdog. |
| `cdebootstrap_cmdline` |  |  |  |
| `cdebootstrap_debug` | `0` | `0`/`1` | Set to "1" to enable cdebootstrap verbose/debug output. |
| `rootfs_mkfs_options` |  |  |  |
| `rootsize` |  |  | / partition size in megabytes, provide it in the form '+\<number\>M' (without quotes), leave empty to use all free space |
| `timeserver` | `time.nist.gov` |  |  |
| `timeserver_http` |  |  | URL that returns the time in the format: YYYY-MM-DD HH:MM:SS. |
| `disable_predictable_nin` | `1` | `0`/`1` | Disable Predictable Network Interface Names. Set to 0 if you want to use predictable network interface names, which means if you use the same SD card on a different RPi board, your network device might be named differently. This will result in the board having no network connectivity. |
| `drivers_to_load` |  |  | Loads additional kernel modules at installation (comma separated and quoted). |
| `online_config` |  |  | URL to extra config that will be executed after installer-config.txt |
| `use_systemd_services` | `0` | `0`/`1` | Use systemd for networking and DNS resolution. |
