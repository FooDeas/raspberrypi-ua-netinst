#!/bin/bash
# shellcheck disable=SC1090
# shellcheck disable=SC1091

variables_reset() {
	# internal variables
	logfile=
	bootdev=
	am_subscript=
	final_action=
	rpi_hardware=
	rpi_hardware_version=
	preinstall_reboot=
	bootpartition=
	rootdev=
	rootpartition=
	wlan_configfile=
	installer_fail_blocking=
	cmdline_custom=

	# config variables
	preset=
	packages=
	firmware_packages=
	mirror=
	mirror_cache=
	release=
	arch=
	hostname=
	boot_volume_label=
	root_volume_label=
	domainname=
	rootpw=
	user_ssh_pubkey=
	root_ssh_pubkey=
	root_ssh_pwlogin=
	ssh_pwlogin=
	username=
	userpw=
	usergpio=
	usergpu=
	usergroups=
	usersysgroups=
	userperms_admin=
	userperms_sound=
	cdebootstrap_cmdline=
	cdebootstrap_debug=
	bootsize=
	bootoffset=
	rootsize=
	timeserver=
	timeserver_http=
	timezone=
	rtc=
	dt_overlays=
	keyboard_layout=
	locales=
	system_default_locale=
	disable_predictable_nin=
	ifname=
	wlan_country=
	wlan_ssid=
	wlan_psk=
	wlan_psk_encrypted=
	ip_addr=
	ip_netmask=
	ip_broadcast=
	ip_gateway=
	ip_nameservers=
	ip_ipv6=
	drivers_to_load=
	online_config=
	gpu_mem=
	console_blank=
	hdmi_type=
	hdmi_tv_res=
	hdmi_monitor_res=
	hdmi_disable_overscan=
	hdmi_system_only=
	usbroot=
	usbboot=
	cmdline=
	rootfstype=
	installer_telnet=
	installer_telnet_host=
	installer_telnet_port=
	installer_retries=
	installer_networktimeout=
	installer_pkg_updateretries=
	installer_pkg_downloadretries=
	hwrng_support=
	watchdog_enable=
	quiet_boot=
	disable_raspberries=
	disable_splash=
	cleanup=
	cleanup_logfiles=
	spi_enable=
	i2c_enable=
	i2c_baudrate=
	sound_enable=
	sound_usb_enable=
	sound_usb_first=
	camera_enable=
	camera_disable_led=
	use_systemd_services=
}

variable_set() {
	local variable="${1}"
	local value="${2}"
	if [ -z "${!variable}" ]; then
		eval "${variable}=\"${value}\""
	fi
}

variable_set_deprecated() {
	local variable_old="${1}"
	local variable_new="${2}"
	if [ -z "${!variable_new}" ] && [ -n "${!variable_old}" ]; then
		eval "${variable_new}=\"${!variable_old}\""
		echo "  Variable '${variable_old}' is deprecated. Variable '${variable_new}' was set instead!"
	fi
}

variables_set_defaults() {
	# backward compatibility of deprecated variables
	echo
	echo "Searching for deprecated variables..."
	variable_set_deprecated enable_watchdog watchdog_enable
	variable_set_deprecated root_ssh_allow root_ssh_pwlogin
	variable_set_deprecated user_is_admin userperms_admin
	if [ -n "${ip_broadcast}" ]; then
		echo "  Variable 'ip_broadcast' is deprecated. This variable will be ignored!"
	fi
	if [ "${installer_telnet}" = "1" ]; then
		echo "'installer_telnet' now accepts 'connect' and 'listen' settings, not '1'."
		echo "'listen' mode is being enabled."
		installer_telnet="listen"
	elif [ "${installer_telnet}" = "0" ]; then
		echo "'installer_telnet' now accepts 'connect' and 'listen' settings, not '0'."
		echo "Neither mode is enabled."
		installer_telnet="none"
	fi

	# set config defaults
	variable_set "preset" "server"
	variable_set "arch" "armhf"
	if [ "${arch}" = "arm64" ]; then
		variable_set "mirror" "http://deb.debian.org/debian/"
	else
		variable_set "mirror" "http://mirrordirector.raspbian.org/raspbian/"
	fi
	variable_set "release" "bookworm"
	variable_set "hostname" "pi"
	variable_set "rootpw" "raspbian"
	variable_set "root_ssh_pwlogin" "1"
	variable_set "userperms_admin" "0"
	variable_set "userperms_sound" "0"
	variable_set "bootsize" "+128M"
	variable_set "bootoffset" "8192"
	variable_set "timeserver" "time.nist.gov"
	variable_set "timezone" "Etc/UTC"
	variable_set "disable_predictable_nin" "1"
	variable_set "ifname" "eth0"
	variable_set "ip_addr" "dhcp"
	variable_set "ip_ipv6" "1"
	variable_set "hdmi_tv_res" "1080p"
	variable_set "hdmi_monitor_res" "1024x768"
	variable_set "hdmi_disable_overscan" "0"
	variable_set "hdmi_system_only" "0"
	variable_set "usbroot" "0"
	variable_set "usbboot" "0"
	variable_set "cmdline" "console=serial0,115200 console=tty1 fsck.repair=yes"
	variable_set "rootfstype" "f2fs"
	variable_set "final_action" "reboot"
	variable_set "installer_telnet" "listen"
	variable_set "installer_telnet_port" "9923"
	variable_set "installer_retries" "3"
	variable_set "installer_networktimeout" "15"
	variable_set "installer_pkg_updateretries" "3"
	variable_set "installer_pkg_downloadretries" "5"
	variable_set "hwrng_support" "1"
	variable_set "watchdog_enable" "0"
	variable_set "cdebootstrap_debug" "0"
	variable_set "quiet_boot" "0"
	variable_set "disable_raspberries" "0"
	variable_set "disable_splash" "0"
	variable_set "cleanup" "0"
	variable_set "cleanup_logfiles" "0"
	variable_set "spi_enable" "0"
	variable_set "i2c_enable" "0"
	variable_set "sound_enable" "0"
	variable_set "sound_usb_enable" "0"
	variable_set "sound_usb_first" "0"
	variable_set "camera_enable" "0"
	variable_set "camera_disable_led" "0"
	variable_set "use_systemd_services" "0"
}

led_sos() {
	local led0=/sys/class/leds/PWR # Power LED
	local led1=/sys/class/leds/ACT # Activity LED
	local led_on
	local led_off

	# Setting leds on and off works the other way round on Pi Zero and Pi Zero W
	# Also led0 (the only led on the Zeros) is the activity led
	if [ "${rpi_hardware_version:0:4}" != "Zero" ]; then
		led_on=1
		led_off=0
	else
		led_on=0
		led_off=1
	fi

	if [ -e "${led0}" ]; then (echo none > "${led0}/trigger" || true) &> /dev/null; else led0=; fi
	if [ -e "${led1}" ]; then (echo none > "${led1}/trigger" || true) &> /dev/null; else led1=; fi
	for i in $(seq 1 3); do
		if [ -n "${led0}" ]; then (echo ${led_on} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "${led1}" ]; then (echo ${led_on} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.225s;
		if [ -n "${led0}" ]; then (echo ${led_off} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "${led1}" ]; then (echo ${led_off} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.15s;
	done
	sleep 0.075s;
	for i in $(seq 1 3); do
		if [ -n "${led0}" ]; then (echo ${led_on} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "${led1}" ]; then (echo ${led_on} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.6s;
		if [ -n "${led0}" ]; then (echo ${led_off} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "${led1}" ]; then (echo ${led_off} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.15s;
	done
	sleep 0.075s;
	for i in $(seq 1 3); do
		if [ -n "${led0}" ]; then (echo ${led_on} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "${led1}" ]; then (echo ${led_on} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.225s;
		if [ -n "${led0}" ]; then (echo ${led_off} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "${led1}" ]; then (echo ${led_off} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.15s;
	done
	sleep 1.225s;
}

inputfile_sanitize() {
	local inputfile
	if [ -z "${1}" ]; then
		echo "No input file specified!"
	else
		inputfile=${1}
		# convert line endings to unix
		dos2unix "${inputfile}"
		# add line feed at the end
		if [ -n "$(tail -c1 "${inputfile}")" ]; then
			echo >> "${inputfile}"
		fi
	fi
}

fail_blocking() {
	installer_fail_blocking=1
	fail
}

fail() {
	local fail_boot_mounted
	echo
	echo "Error: The installation could not be completed!"

	# copy logfile to /boot/raspberrypi-ua-netinst/ to preserve it.
	# test whether the sd card is still mounted on /boot and if not, mount it.
	if [ ! -f /boot/bootcode.bin ]; then
		mount "${bootpartition}" /boot
		fail_boot_mounted=true
	fi
	# root and user passwords are deleted from logfile before it is written to the filesystem
	sed "/rootpw/d;/userpw/d" "${logfile}" > /boot/raspberrypi-ua-netinst/error-"$(date +%Y%m%dT%H%M%S)".log
	sync

	if [ -e "${installer_retriesfile}" ]; then
		inputfile_sanitize "${installer_retriesfile}"
		source "${installer_retriesfile}"
	fi
	variable_set "installer_retries" "3"
	installer_retries=$((installer_retries-1))
	if [ "${installer_retries}" -ge "0" ]; then
		echo "installer_retries=${installer_retries}" > "${installer_retriesfile}"
		sync
	fi
	if [ "${installer_retries}" -le "0" ] || [ "${installer_fail_blocking}" = "1" ]; then
		if [ "${installer_retries}" -le "0" ]; then
			echo "  The maximum number of retries is reached!"
			echo "  Check the logfiles for errors. Then delete or edit \"installer-retries.txt\" in installer folder to (re)set the counter."
		fi
		sleep 3s
		while true; do
			led_sos
		done &
		exit
	else
		echo "  ${installer_retries} retries left."
	fi

	if [ -e "${installer_swapfile}" ]; then
		swapoff "${installer_swapfile}" 2> /dev/null
		rm -f "${installer_swapfile}"
	fi

	# if we mounted /boot in the fail command, unmount it.
	if [ "${fail_boot_mounted}" = true ]; then
		sync
		umount /boot
	fi

	echo "  You have 10 seconds to press ENTER to get a shell or it will be retried automatically."
	read -rt 10 || reboot && exit
	sh
}

# sanitizes variables that use comma separation
variable_sanitize() {
	local variable="${1}"
	local value="${!1}"
	value="$(echo "${value}" | tr ' ' ',')"
	while [ "${value:0:1}" == "," ]; do
		value="${value:1}"
	done
	while [ "${value: -1}" == "," ]; do
		value="${value:0:-1}"
	done
	while echo "${value}" | grep -q ",,"; do
		value="${value//,,/,}"
	done
	eval "${variable}=\"${value}\""
}

variable_deduplicate() {
	local variable="${1}"
	local values=()
	eval values=\(\"\$\{"${variable}"[@]\}\"\)
	local exists
	local cleaned=()
	for value in "${values[@]}"; do
		exists=0
		for search in "${cleaned[@]}"; do
			if [ "${value}" == "${search}" ]; then
				exists=1
				break
			fi
		done
		if [ "${exists}" == "0" ]; then
			cleaned+=("${value}")
		fi
	done
	for i in "${cleaned[@]}"; do
		echo "result: ${i}"
	done
	eval "${variable}"=\(\"\$\{cleaned[@]\}\"\)
}

convert_listvariable() {
	local variable="${1}"
	variable_sanitize "${variable}"
	local value="${!1}"
	eval "${variable}=\"$(echo "${value}" | tr ',' ' ')\""
}

install_files() {
	local file_to_read="${1}"
	echo "Adding files & folders listed in /boot/raspberrypi-ua-netinst/config/files/${file_to_read}..."
	inputfile_sanitize "/rootfs/boot/raspberrypi-ua-netinst/config/files/${file_to_read}"
	grep -v "^[[:space:]]*#\|^[[:space:]]*$" "/rootfs/boot/raspberrypi-ua-netinst/config/files/${file_to_read}" | while read -r line; do
		owner=$(echo "${line}" | awk '{ print $1 }')
		perms=$(echo "${line}" | awk '{ print $2 }')
		file=$(echo "${line}" | awk '{ print $3 }')
		echo "  ${file}"
		if [ ! -d "/rootfs/boot/raspberrypi-ua-netinst/config/files/root${file}" ]; then
			mkdir -p "/rootfs$(dirname "${file}")"
			cp "/rootfs/boot/raspberrypi-ua-netinst/config/files/root${file}" "/rootfs${file}"
		else
			mkdir -p "/rootfs/${file}"
		fi
		chmod "${perms}" "/rootfs${file}"
		chroot /rootfs chown "${owner}" "${file}"
	done
	echo
}

set_filter() {
	filterstring="^$"
	filterstring+="|^Setcap failed on \S.*, falling back to setuid$"
	filterstring+="|^dpkg: warning: ignoring pre-dependency problem"'!'"$"
	filterstring+="|^dpkg: regarding \.\.\.\/\S.* containing \S.*, pre-dependency problem:$"
	filterstring+="|^dpkg: \S.*: dependency problems, but configuring anyway as you requested:$"
	filterstring+="|^ \S.* pre-depends on \S.*$"
	filterstring+="|^ \S.* depends on \S.*; however:$"
	filterstring+="|^  \S.* is unpacked, but has never been configured\.$"
	filterstring+="|^  (Package )?\S.* is not installed\.$"
	filterstring+="|^  \S.* provides \S.* but is unpacked but not configured\.$"
	filterstring+="|^debconf: delaying package configuration, since apt-utils is not installed$"
	filterstring+="|^\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*$"
	filterstring+="|^All rc\.d operations denied by policy$"
	filterstring+="|^[:space:]*E[:space:]*$"
	filterstring+="|^[:space:]*:[:space:]*$"
	filterstring+="|Can not write log \(Is \/dev\/pts mounted\?\) - posix_openpt \(19: No such device\)$"
	filterstring+="|Can not write log \(Is \/dev\/pts mounted\?\) - posix_openpt \(2: No such file or directory\)$"
	filterstring+="|^update-rc\.d: warning: start and stop actions are no longer supported; falling back to defaults$"
	filterstring+="|^invoke-rc\.d: policy-rc\.d denied execution of start\.$"
	filterstring+="|^Failed to set capabilities on file \`\S.*' \(Invalid argument\)$"
	filterstring+="|^The value of the capability argument is not permitted for a file\. Or the file is not a regular \(non-symlink\) file$"
	filterstring+="|^Failed to read \S.*\. Ignoring: No such file or directory$"
	filterstring+="|\(Reading database \.\.\. $"
	filterstring+="|\(Reading database \.\.\. [0..9]{1,3}\%"
	filterstring+="|^E$"
	filterstring+="|^: $"
}

output_filter() {
	while IFS= read -r line; do
		if [[ ! "${line}" =~ ${filterstring} ]]; then
			echo "  ${line}"
		fi
	done
}

line_add() {
	local variable="${1}"
	local value="${2}"
	if [ -z "${!variable}" ]; then
		eval "${variable}=\"${value}\""
	else
		eval "${variable}=\"${!variable} ${value}\""
	fi
}

line_add_if_boolean() {
	local variable="${1}"
	local target="${2}"
	local value="${3}"
	local value_else="${4}"
	if [ "${!variable}" = "1" ]; then
		line_add "${target}" "${value}"
	else
		line_add "${target}" "${value_else}"
	fi
}

line_add_if_boolean_not() {
	local variable="${1}"
	local target="${2}"
	local value="${3}"
	local value_else="${4}"
	if [ "${!variable}" = "0" ]; then
		line_add "${target}" "${value}"
	else
		line_add "${target}" "${value_else}"
	fi
}

line_add_if_set() {
	local variable="${1}"
	local target="${2}"
	local value="${3}"
	local value_else="${4}"
	if [ -n "${!variable}" ]; then
		line_add "${target}" "${value}"
	else
		line_add "${target}" "${value_else}"
	fi
}

config_check() {
	local configfile="${1}"
	local option="${2}"
	local value="${3}"
	if [ "$(grep -c "^${option}=.*" "${configfile}")" -eq 1 ] && [ "$(grep -c "^${option}=${value}\>" "${configfile}")" -eq 1 ]; then
		return 0
	fi
	return 1
}

config_set() {
	local configfile="${1}"
	local option="${2}"
	local value="${3}"
	if ! config_check "${1}" "${2}" "${3}"; then
		sed -i "s/^#\(${option}=${value}\)/\1/" "${configfile}"
		if [ "$(grep -c "^${option}=.*" "${configfile}")" -ne 1 ]; then
			sed -i "s/^\(${option}=.*\)/#\1/" "${configfile}"
			echo "${option}=${value}" >> "${configfile}"
		fi
	fi
}

dtoverlay_enable() {
	local configfile="${1}"
	local dtoverlay="${2}"
	local value="${3}"
	sed -i "s/^#\(dtoverlay=${dtoverlay}=${value}\)/\1/" "${configfile}"
	if [ "$(grep -c "^dtoverlay=${dtoverlay}" "${configfile}")" -ne 1 ]; then
		sed -i "s/^\(dtoverlay=${dtoverlay}\)/#\1/" "${configfile}"
		if [ -z "${value}" ]; then
			echo "dtoverlay=${dtoverlay}" >> "${configfile}"
		else
			echo "dtoverlay=${dtoverlay}=${value}" >> "${configfile}"
		fi
	fi
}

module_enable() {
	local module="${1}"
	local purpose="${2}"
	if [ "${init_system}" = "systemd" ]; then
		echo "${module}" > "/rootfs/etc/modules-load.d/${purpose}.conf"
	else
		echo "${module}" >> /rootfs/etc/modules
	fi
}

#######################
###    INSTALLER    ###
#######################

# clear variables
variables_reset

# preset installer variables
logfile=/tmp/raspberrypi-ua-netinst.log
installer_retriesfile=/boot/raspberrypi-ua-netinst/installer-retries.txt
installer_swapfile=/rootfs/installer-swap
wlan_configfile=/tmp/wpa_supplicant.conf
rootdev=/dev/mmcblk0
tmp_bootfs=/tmp/bootfs
set_filter

mkdir -p /proc
mkdir -p /sys
mkdir -p /boot
mkdir -p /usr/bin
mkdir -p /usr/sbin
mkdir -p /var/run
mkdir -p /etc/raspberrypi-ua-netinst
mkdir -p /rootfs
mkdir -p /tmp
mkdir -p "${tmp_bootfs}"
mkdir -p /opt/busybox/bin

/bin/busybox --install /opt/busybox/bin/
ln -s /opt/busybox/bin/sh /bin/sh

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/busybox/bin
# put PATH in /etc/profile so it's also available when we get a busybox shell
echo "export PATH=${PATH}" > /etc/profile

mount -t proc proc /proc
ln -sf /proc/mounts /etc/mtab
mount -t sysfs sysfs /sys

mount -t tmpfs -o size=64k,mode=0755 tmpfs /dev
mkdir /dev/pts
mount -t devpts devpts /dev/pts

echo /opt/busybox/bin/mdev > /proc/sys/kernel/hotplug
mdev -s

klogd -c 1
sleep 3s

# set screen blank period to an hour unless consoleblank=0 on cmdline
# hopefully the install should be done by then
if grep -qv  "consoleblank=0" /proc/cmdline; then
	echo -en '\033[9;60]'
fi

# Config serial output device
echo
echo -n "Waiting for serial device... "
until [ -e /dev/ttyAMA0 ]; do sleep 1s; done
echo "OK"
if cmp -s /proc/device-tree/aliases/uart0 /proc/device-tree/aliases/serial0; then
	ln -s /dev/ttyAMA0 /dev/serial0
elif cmp -s /proc/device-tree/aliases/uart0 /proc/device-tree/aliases/serial1; then
	ln -s /dev/ttyAMA0 /dev/serial1
fi
if cmp -s /proc/device-tree/aliases/uart1 /proc/device-tree/aliases/serial0; then
	ln -s /dev/ttyS0 /dev/serial0
elif cmp -s /proc/device-tree/aliases/uart1 /proc/device-tree/aliases/serial1; then
	ln -s /dev/ttyS0 /dev/serial1
fi
if grep -q "console=tty1" /proc/cmdline; then
	mkfifo serial.pipe
	tee < serial.pipe /dev/serial0 &
	exec &> serial.pipe
	rm serial.pipe
	echo > /dev/serial0
	echo "Printing console to serial output started."
fi

# Detect boot device
echo
echo "Searching for boot device..."
until [ -n "${bootdev}" ]; do
	if [ -e "/dev/mmcblk0p1" ]; then
		echo "SD card detected."
		mount /dev/mmcblk0p1 /boot
		if [ -e /boot/bootcode.bin ]; then
			echo "Boot files found on SD card."
			bootdev=/dev/mmcblk0
			bootpartition=/dev/mmcblk0p1
		fi
		umount /boot
	else
		if [ -e "/dev/sda1" ]; then
			echo "USB drive detected."
			mount /dev/sda1 /boot
			if [ -e /boot/bootcode.bin ]; then
				echo "Boot files found on USB drive."
				bootdev=/dev/sda
				bootpartition=/dev/sda1
			fi
			umount /boot
		fi
	fi
	if [ -z "${bootdev}" ]; then sleep 1s; fi
done

# Check if there's an alternative rcS file and excute it
# instead of this file. Only do this if this isn't the
# alternative script already
if [ -z "${am_subscript}" ]; then
	mkdir -p /boot
	mount "${bootpartition}" /boot
	if [ -e "/boot/raspberrypi-ua-netinst/rcS" ]; then
		cp /boot/raspberrypi-ua-netinst/rcS /opt/raspberrypi-ua-netinst/custom-rcS
		umount /boot
		echo "=================================================="
		echo "=== Start executing alternative rcS =============="
		echo "--------------------------------------------------"
		export am_subscript=true
		source /opt/raspberrypi-ua-netinst/custom-rcS
		echo "--------------------------------------------------"
		echo "=== Execution of alternative rcS finished ========"
		echo "=================================================="
		${final_action} || reboot || exit
	else
		# Clean up, so the rest of the script continues as expected
		umount /boot
	fi
fi

# link shared libraries
/sbin/ldconfig

# redirect stdout and stderr also to logfile
# http://stackoverflow.com/questions/3173131/redirect-copy-of-stdout-to-log-file-from-within-bash-script-itself/6635197#6635197
mkfifo "${logfile}.pipe"
tee < "${logfile}.pipe" "${logfile}" &
exec &> "${logfile}.pipe"
rm "${logfile}.pipe"

# detecting model based on http://elinux.org/RPi_HardwareHistory
rpi_hardware="$(grep Revision /proc/cpuinfo | cut -d " " -f 2 | sed 's/^1000//')"
case "${rpi_hardware}" in
	"0002") rpi_hardware_version="B" ;;
	"0003") rpi_hardware_version="B" ;;
	"0004") rpi_hardware_version="B" ;;
	"0005") rpi_hardware_version="B" ;;
	"0006") rpi_hardware_version="B" ;;
	"0007") rpi_hardware_version="A" ;;
	"0008") rpi_hardware_version="A" ;;
	"0009") rpi_hardware_version="A" ;;
	"000d") rpi_hardware_version="B" ;;
	"000e") rpi_hardware_version="B" ;;
	"000f") rpi_hardware_version="B" ;;
	"0010") rpi_hardware_version="B+" ;;
	"0011") rpi_hardware_version="Compute Module 1" ;;
	"0012") rpi_hardware_version="A+" ;;
	"0013") rpi_hardware_version="B+" ;;
	"0014") rpi_hardware_version="Compute Module 1" ;;
	"0015") rpi_hardware_version="A+" ;;
	"a01040") rpi_hardware_version="2 Model B" ;;
	"a01041") rpi_hardware_version="2 Model B" ;;
	"a21041") rpi_hardware_version="2 Model B" ;;
	"a22042") rpi_hardware_version="2 Model B+" ;;
	"900021") rpi_hardware_version="A+" ;;
	"900032") rpi_hardware_version="B+" ;;
	"900092") rpi_hardware_version="Zero" ;;
	"900093") rpi_hardware_version="Zero" ;;
	"920093") rpi_hardware_version="Zero" ;;
	"9000c1") rpi_hardware_version="Zero W" ;;
	"a02082") rpi_hardware_version="3 Model B" ;;
	"a020a0") rpi_hardware_version="Compute Module 3 (Lite)" ;;
	"a22082") rpi_hardware_version="3 Model B" ;;
	"a32082") rpi_hardware_version="3 Model B" ;;
	"a020d3") rpi_hardware_version="3 Model B+" ;;
	"9020e0") rpi_hardware_version="3 Model A+" ;;
	"a02100") rpi_hardware_version="Compute Module 3+" ;;
	"a03111") rpi_hardware_version="4 Model B" ;;
	"b03111") rpi_hardware_version="4 Model B" ;;
	"b03112") rpi_hardware_version="4 Model B" ;;
	"b03114") rpi_hardware_version="4 Model B" ;;
	"b03115") rpi_hardware_version="4 Model B" ;;
	"c03111") rpi_hardware_version="4 Model B" ;;
	"c03112") rpi_hardware_version="4 Model B" ;;
	"c03114") rpi_hardware_version="4 Model B" ;;
	"c03115") rpi_hardware_version="4 Model B" ;;
	"d03114") rpi_hardware_version="4 Model B" ;;
	"d03115") rpi_hardware_version="4 Model B" ;;
	"902120") rpi_hardware_version="Zero 2 W" ;;
	*) rpi_hardware_version="unknown (${rpi_hardware})" ;;
esac

echo
echo "=================================================="
echo "raspberrypi-ua-netinst"
echo "=================================================="
echo "Revision __VERSION__"
echo "Built on __DATE__"
echo "Running on Raspberry Pi version ${rpi_hardware_version}"
echo "=================================================="
echo "https://github.com/FooDeas/raspberrypi-ua-netinst/"
echo "=================================================="

echo -n "Remounting TempFS... "
mount -o remount,size=80% / || fail
echo "OK"

echo -n "Mounting boot partition... "
mount "${bootpartition}" /boot || fail
echo "OK"

# copy boot data to safety
echo -n "Copying boot files... "
cp -r /boot/* "${tmp_bootfs}"/ || fail
echo "OK"

# Read installer-config.txt
if [ -e "${tmp_bootfs}"/raspberrypi-ua-netinst/config/installer-config.txt ]; then
	echo "Executing installer-config.txt..."
	inputfile_sanitize "${tmp_bootfs}"/raspberrypi-ua-netinst/config/installer-config.txt
	source "${tmp_bootfs}"/raspberrypi-ua-netinst/config/installer-config.txt
	echo "OK"
fi

# Setting default variables
variables_set_defaults

preinstall_reboot=0
echo
echo "Checking if config.txt needs to be modified before starting installation..."
# HDMI settings
if [ "${hdmi_system_only}" = "0" ]; then
	echo -n "  Setting HDMI options... "
	if [ "${hdmi_type}" = "tv" ] || [ "${hdmi_type}" = "monitor" ]; then
		if ! config_check "/boot/config.txt" "hdmi_ignore_edid" "0xa5000080"; then config_set "/boot/config.txt" "hdmi_ignore_edid" "0xa5000080" >> /boot/config.txt; preinstall_reboot=1; fi
		if ! config_check "/boot/config.txt" "hdmi_drive" "2"; then config_set "/boot/config.txt" "hdmi_drive" "2" >> /boot/config.txt; preinstall_reboot=1; fi
		if [ "${hdmi_type}" = "tv" ]; then
			if ! config_check "/boot/config.txt" "hdmi_group" "1"; then config_set "/boot/config.txt" "hdmi_group" "1" >> /boot/config.txt; preinstall_reboot=1; fi
			if [ "${hdmi_tv_res}" = "720p" ]; then
				if ! config_check "/boot/config.txt" "hdmi_mode" "4"; then config_set "/boot/config.txt" "hdmi_mode" "4" >> /boot/config.txt; preinstall_reboot=1; fi
			elif [ "${hdmi_tv_res}" = "1080i" ]; then
				if ! config_check "/boot/config.txt" "hdmi_mode" "5"; then config_set "/boot/config.txt" "hdmi_mode" "5" >> /boot/config.txt; preinstall_reboot=1; fi
			else
				if ! config_check "/boot/config.txt" "hdmi_mode" "16"; then config_set "/boot/config.txt" "hdmi_mode" "16" >> /boot/config.txt; preinstall_reboot=1; fi
			fi
		elif [ "${hdmi_type}" = "monitor" ]; then
			if ! config_check "/boot/config.txt" "hdmi_group" "2"; then config_set "/boot/config.txt" "hdmi_group" "2" >> /boot/config.txt; preinstall_reboot=1; fi
			if [ "${hdmi_monitor_res}" = "640x480" ]; then
				if ! config_check "/boot/config.txt" "hdmi_mode" "4"; then config_set "/boot/config.txt" "hdmi_mode" "4" >> /boot/config.txt; preinstall_reboot=1; fi
			elif [ "${hdmi_monitor_res}" = "800x600" ]; then
				if ! config_check "/boot/config.txt" "hdmi_mode" "9"; then config_set "/boot/config.txt" "hdmi_mode" "9" >> /boot/config.txt; preinstall_reboot=1; fi
			elif [ "${hdmi_monitor_res}" = "1280x1024" ]; then
				if ! config_check "/boot/config.txt" "hdmi_mode" "35"; then config_set "/boot/config.txt" "hdmi_mode" "35" >> /boot/config.txt; preinstall_reboot=1; fi
			else
				if ! config_check "/boot/config.txt" "hdmi_mode" "16"; then config_set "/boot/config.txt" "hdmi_mode" "16" >> /boot/config.txt; preinstall_reboot=1; fi
			fi
		fi
	fi
	if [ "${hdmi_disable_overscan}" = "1" ]; then
		if ! config_check "/boot/config.txt" "disable_overscan" "1"; then config_set "/boot/config.txt" "disable_overscan" "1"; preinstall_reboot=1; fi
	fi
	echo "OK"
fi
# RTC
if [ -n "${rtc}" ] ; then
	echo -n "  Enabling RTC configuration... "
	if ! grep -q "^dtoverlay=i2c-rtc,${rtc}\>" /boot/config.txt; then
		dtoverlay_enable "/boot/config.txt" "i2c-rtc,${rtc}"
		preinstall_reboot=1
	fi
	echo "OK"
fi
# MSD boot
if [ "${usbboot}" = "1" ] ; then
	echo -n "  Checking USB boot flag... "
	if [ "${rpi_hardware_version}" = "A" ] || [ "${rpi_hardware_version}" = "A+" ] || [ "${rpi_hardware_version}" = "B" ] || [ "${rpi_hardware_version}" = "B+" ] || [ "${rpi_hardware_version}" = "Zero" ] || [ "${rpi_hardware_version}" = "Zero W" ] || [ "${rpi_hardware_version}" = "Compute Module 1" ]; then
		echo -e "\n    Your device does not allow booting from USB. Disable booting from USB in installer-config.txt to proceed."
		fail_blocking
	elif [ "${rpi_hardware_version}" = "2 Model B" ] || [ "${rpi_hardware_version}" = "2 Model B+" ] || [ "${rpi_hardware_version}" = "3 Model A" ] || [ "${rpi_hardware_version}" = "3 Model A+" ] || [ "${rpi_hardware_version}" = "3 Model B" ] || [ "${rpi_hardware_version}" = "Zero 2 W" ] || [ "${rpi_hardware_version}" = "Compute Module 3 (Lite)" ] || [ "${rpi_hardware_version}" = "Compute Module 3+" ]; then
		msd_boot_enabled="$(vcgencmd otp_dump | grep 17: | cut -b 4-5)"
		msd_boot_enabled="$(printf "%s" "${msd_boot_enabled}" | xxd -r -p | xxd -b | cut -d' ' -f2 | cut -b 3)"
		if [ "${msd_boot_enabled}" = "0" ]; then
			if ! config_check "/boot/config.txt" "program_usb_boot_mode" "1"; then
				echo -e "\n    Set flag to allow USB boot on next reboot. "
				config_set "/boot/config.txt" "program_usb_boot_mode" "1"
				preinstall_reboot=1;
			else
				echo -e "\n    Enabling USB boot flag failed!"
				echo "    Your device does not allow booting from USB. Disable booting from USB in installer-config.txt to proceed."
				fail_blocking
			fi
		else
			sed -i "/^program_usb_boot_mode=1/d" "/boot/config.txt"
		fi
	fi
	echo "OK"
fi
echo "OK"
# Reboot if needed
if [ "${preinstall_reboot}" = "1" ]; then
	echo
	echo "Rebooting in 3 seconds!"
	sleep 3s
	reboot && exit
fi
unset preinstall_reboot

echo
echo -n "Unmounting boot partition... "
sync
umount /boot || fail
echo "OK"

echo
echo "Network configuration:"
echo "  ifname = ${ifname}"
echo "  ip_addr = ${ip_addr}"
echo "  ip_ipv6 = ${ip_ipv6}"

if [ "${ip_addr}" != "dhcp" ]; then
	ip_addr_o1="$(echo "${ip_addr}" | awk -F. '{print $1}')"
	ip_addr_o2="$(echo "${ip_addr}" | awk -F. '{print $2}')"
	ip_addr_o3="$(echo "${ip_addr}" | awk -F. '{print $3}')"
	ip_addr_o4="$(echo "${ip_addr}" | awk -F. '{print $4}')"
	if [ -z "${ip_netmask}" ]; then
		if [ "${ip_addr_o1}" = "10" ]; then
			ip_netmask="255.0.0.0"
		elif [ "${ip_addr_o1}" = "172" ]; then
			ip_netmask_subnet="$((ip_addr_o2-16))"
			if [ "${ip_netmask_subnet}" -ge 0 ] && [ "${ip_netmask_subnet}" -lt 16 ]; then
				ip_netmask="255.255.0.0"
			fi
			ip_netmask_subnet=
		elif [ "${ip_addr_o1}" = "192" ] &&  [ "${ip_addr_o2}" = "168" ]; then
			ip_netmask="255.255.255.0"
		fi
		if [ -n "${ip_netmask}" ]; then
			echo "  ip_netmask = ${ip_netmask} (autodetected)"
		else
			echo "  ip_netmask = missing!"
		fi
	else
		echo "  ip_netmask = ${ip_netmask}"
	fi

	if [ -n "${ip_netmask}" ]; then
		ip_netmask_o1="$(echo "${ip_netmask}" | awk -F. '{print $1}')"
		ip_netmask_o2="$(echo "${ip_netmask}" | awk -F. '{print $2}')"
		ip_netmask_o3="$(echo "${ip_netmask}" | awk -F. '{print $3}')"
		ip_netmask_o4="$(echo "${ip_netmask}" | awk -F. '{print $4}')"
		ip_netmask_oi1="$((0xFF ^ ip_netmask_o1))"
		ip_netmask_oi2="$((0xFF ^ ip_netmask_o2))"
		ip_netmask_oi3="$((0xFF ^ ip_netmask_o3))"
		ip_netmask_oi4="$((0xFF ^ ip_netmask_o4))"
		ip_broadcast_o1="$((ip_addr_o1 & ip_netmask_o1 | ip_netmask_oi1))"
		ip_broadcast_o2="$((ip_addr_o2 & ip_netmask_o2 | ip_netmask_oi2))"
		ip_broadcast_o3="$((ip_addr_o3 & ip_netmask_o3 | ip_netmask_oi3))"
		ip_broadcast_o4="$((ip_addr_o4 & ip_netmask_o4 | ip_netmask_oi4))"
		ip_broadcast="${ip_broadcast_o1}"."${ip_broadcast_o2}"."${ip_broadcast_o3}"."${ip_broadcast_o4}"
		echo "  ip_broadcast = ${ip_broadcast} (autodetected)"
	fi

	if [ -n "${ip_gateway}" ]; then
		echo "  ip_gateway = ${ip_gateway}"
	else
		echo "  ip_gateway = missing!"
	fi
	if [ -n "${ip_nameservers}" ]; then
		echo "  ip_nameservers = ${ip_nameservers}"
	else
		echo "  ip_nameservers = missing!"
	fi
fi

if echo "${ifname}" | grep -q "wlan"; then
	echo "netdev:x:111:" >> /etc/group
	if [ -e "${tmp_bootfs}"/raspberrypi-ua-netinst/config/wpa_supplicant.conf ]; then
		cp "${tmp_bootfs}"/raspberrypi-ua-netinst/config/wpa_supplicant.conf "${wlan_configfile}"
		inputfile_sanitize "${wlan_configfile}"
	else
		echo "  wlan_ssid = ${wlan_ssid}"
		if [ -z "${wlan_psk_encrypted}" ]; then
			echo "  wlan_psk = ${wlan_psk}"
			wlan_psk_encrypted="$(wpa_passphrase "${wlan_ssid}" "${wlan_psk}" | grep "psk=" | grep -v "#" | sed "s/.*psk=\(.*\)/\1/")"
		fi
		echo "  wlan_psk_encrypted = ${wlan_psk_encrypted}"
		{
			echo "network={"
			echo "    scan_ssid=1"
			echo "    ssid=\"${wlan_ssid}\""
			echo "    psk=${wlan_psk_encrypted}"
			echo "}"
		} > ${wlan_configfile}
	fi
	if [ -n "${wlan_country}" ] && ! grep -q "country=" "${wlan_configfile}"; then
		echo "country=${wlan_country}" >> "${wlan_configfile}"
	fi
fi

echo "  online_config = ${online_config}"
echo

# create symlink for other kernel modules if needed
if [ ! -e "/lib/modules/$(uname -r)" ]; then
	echo "Kernel modules for the kernel version \"$(uname -r)\" could not be found. Searching for alternatives..."
	if [[ "$(uname -r)" =~ -v7\+$ ]]; then
		kernel_modulepath="$(find /lib/modules/ -maxdepth 1 -type d ! -path /lib/modules/ | grep -e "[^/]\+-v7+$" | head -1)"
	elif [[ "$(uname -r)" =~ -v7l\+$ ]]; then
		kernel_modulepath="$(find /lib/modules/ -maxdepth 1 -type d ! -path /lib/modules/ | grep -e "[^/]\+-v7l+$" | head -1)"
	else
		kernel_modulepath="$(find /lib/modules/ -maxdepth 1 -type d ! -path /lib/modules/ | grep -ve "[^/]\+-v7+$" | head -1)"
	fi
	if [ -z "${kernel_modulepath}" ] ; then
		echo "ERROR: No kernel modules could be found!"
		fail_blocking
	fi
	#kernel_modulename="$("${kernel_modulepath}" | grep -oe "[^/]\+$"\")"
	echo "  Using modules of kernel version \"$(echo "${kernel_modulepath}" | grep -oe "[^/]\+$")\"."
	ln -s "${kernel_modulepath}" "/lib/modules/$(uname -r)"
fi

# depmod needs to update modules.dep before using modprobe
depmod -a
find /sys/ -name modalias -print0 | xargs -0 sort -u | xargs modprobe -abq
if [ -n "${drivers_to_load}" ]; then
	echo "Loading additional kernel modules:"
	convert_listvariable drivers_to_load
	for driver in ${drivers_to_load}
	do
		echo -n "  Loading module '${driver}'... "
		modprobe "${driver}" || fail
		echo "OK"
	done
	echo
fi

if [ -n "${rtc}" ] ; then
	echo -n "Ensuring RTC module has been loaded... "
	modprobe "rtc-${rtc}" || fail
	echo "OK"
	echo -n "Checking hardware clock access... "
	mdev -s
	sleep 3s
	/opt/busybox/bin/hwclock --show &> /dev/null || fail
	echo "OK"
fi

echo -n "Waiting for ${ifname}... "
for i in $(seq 1 "${installer_networktimeout}"); do
	if ifconfig "${ifname}" &> /dev/null; then
		break
	fi
	if [ "${i}" -eq "${installer_networktimeout}" ]; then
		echo "FAILED"
		fail
	fi
	sleep 1
	echo -n "${i}.. "
done
echo "OK"

if [ "${ifname}" != "eth0" ]; then
	# Replace eth0 as udhcpc dns interface
	sed -i "s/PEERDNS_IF=.*/PEERDNS_IF=${ifname}/g" /etc/udhcpc/default.script
	# wlan* is a wireless interface and wpa_supplicant must connect to wlan
	if echo "${ifname}" | grep -q "wlan"; then
		echo "Starting wpa_supplicant..."
		if [ -e "${wlan_configfile}" ]; then
			wpa_supplicant -B -Dnl80211 -c"${wlan_configfile}" -i"${ifname}" | sed 's/^/  /'
			if [ "${PIPESTATUS[0]}" -ne 0 ]; then
				echo "  nl80211 driver didn't work. Trying generic driver (wext)..."
				wpa_supplicant -B -Dwext -c"${wlan_configfile}" -i"${ifname}" | sed 's/^/  /'
				if [ "${PIPESTATUS[0]}" -ne 0 ]; then
					fail
				fi
			fi
			echo "OK"
		else
			echo "  wpa_supplicant.conf could not be found."
			fail
		fi
	fi
fi

if [ "${ip_addr}" = "dhcp" ]; then
	echo -n "Configuring ${ifname} with DHCP... "

	if udhcpc -R -i "${ifname}" &> /dev/null; then
		ifconfig "${ifname}" | grep -F addr: | awk '{print $2}' | cut -d: -f2
	else
		echo "FAILED"
		fail
	fi
else
	echo -n "Configuring ${ifname} with static ip ${ip_addr}... "
	ifconfig "${ifname}" up inet "${ip_addr}" netmask "${ip_netmask}" broadcast "${ip_broadcast}" || fail
	route add default gw "${ip_gateway}" || fail
	echo -n > /etc/resolv.conf
	for i in ${ip_nameservers}; do
		echo "nameserver ${i}" >> /etc/resolv.conf
	done
	echo "OK"
fi

if [ "${ip_ipv6}" = "1" ]; then
	echo -n "Enabling IPv6 support... "
	modprobe ipv6 || fail
	echo "OK"
fi

# Start telnet console output
if [ "${installer_telnet}" = "listen" ] || [ "${installer_telnet}" = "connect" ]; then
	mkfifo telnet.pipe
	mkfifo /dev/installer-telnet
	tee < telnet.pipe /dev/installer-telnet &
	if [ "${installer_telnet}" = "listen" ]; then
		nc_opts=(-klC -p 23)
	else # connect
		if [ -z "${installer_telnet_host}" ]; then
			echo "'installer_telnet' set to 'connect' but no 'installer_telnet_host' specified."
			echo "Telnet mode will not be enabled."
		fi
		nc_opts=(-C "${installer_telnet_host}" "${installer_telnet_port}")
	fi
	while IFS= read -r line; do
		if [[ ! "${line}" =~ userpw|rootpw ]]; then
			echo "${line}"
		fi
	done < "/dev/installer-telnet" | /bin/nc "${nc_opts[@]}" > /dev/null &
	exec &> telnet.pipe
	rm telnet.pipe
	echo "Printing console to telnet output started."
fi

# This will record the time to get to this point
PRE_NETWORK_DURATION=$(date +%s)

date_set=false
if [ "${date_set}" = "false" ]; then
	# set time with rdate
	# time server addresses taken from http://tf.nist.gov/tf-cgi/servers.cgi
	echo -n "Set time using timeserver "
	for ts in ${timeserver} time.nist.gov time-{a..e}-{g,b,wwv}.nist.gov utcnist{,2}.colorado.edu; do
		echo -n "'${ts}'... "
		if rdate "${ts}" &> /dev/null; then
			echo "OK"
			date_set=true
			break
		fi
	done

	if [ "${date_set}" = "false" ]; then
		echo "Failed to set time via rdate. Switched to HTTP."
		# Try to set time via http to work behind proxies.
		timeservers_http="${timeserver_http} deb.debian.org kernel.org example.com archive.org icann.org iana.org ietf.org"
		date_re=$'.*^[[:space:]]*Date:([^\r\n]+)'
		echo -n "Set time using HTTP Date header "
		for ts_http in ${timeservers_http}; do
			echo -n "'${ts_http}'... "
			http_date="$(wget --method=HEAD -qSO- -t 2 -T 3 --max-redirect=0 "${ts_http}" 2>&1)"
			if [[ $http_date =~ $date_re && -n "${BASH_REMATCH[1]//[[:space:]]}" ]] && date -s "${BASH_REMATCH[1]}" &> /dev/null; then
				echo "OK"
				date_set=true
				break
			fi
		done
	fi
fi
if [ "${date_set}" != "true" ]; then
	echo
	echo "FAILED to set the time, so things are likely to fail now..."
	echo "Check your connection or firewall."
fi

# Record the time now that the time is set to a correct value
STARTTIME=$(date +%s)
# And substract the PRE_NETWORK_DURATION from STARTTIME to get the
# REAL starting time.
REAL_STARTTIME=$((STARTTIME - PRE_NETWORK_DURATION))
echo
echo "Installation started at $(date --date="@${REAL_STARTTIME}" --utc) (UTC)."
echo

if [ -n "${online_config}" ]; then
	echo -n "Downloading online config from ${online_config}... "
	wget -q -O /opt/raspberrypi-ua-netinst/installer-config_online.txt "${online_config}" &> /dev/null || fail
	echo "OK"

	echo -n "Executing online-config.txt... "
	inputfile_sanitize /opt/raspberrypi-ua-netinst/installer-config_online.txt
	source /opt/raspberrypi-ua-netinst/installer-config_online.txt
	variables_set_defaults
	echo "OK"
fi

# prepare rootfs options
case "${rootfstype}" in
	"btrfs")
		kernel_module=true
		if [ -z "${rootfs_mkfs_options}" ]; then
			if [ -n "${root_volume_label}" ]; then
				rootfs_mkfs_options="-L ${root_volume_label} -f"
			else
				rootfs_mkfs_options="-f"
			fi
		fi
		rootfs_install_mount_options="noatime"
		rootfs_mount_options="noatime"
	;;
	"ext4")
		if [ -z "${rootfs_mkfs_options}" ]; then
			if [ -n "${root_volume_label}" ]; then
				rootfs_mkfs_options="-L ${root_volume_label}"
			else
				rootfs_mkfs_options=
			fi
		fi
		rootfs_install_mount_options="noatime,data=writeback,nobarrier,noinit_itable"
		rootfs_mount_options="errors=remount-ro,noatime"
	;;
	"f2fs")
		if [ -z "${rootfs_mkfs_options}" ]; then
			if [ -n "${root_volume_label}" ]; then
				rootfs_mkfs_options="-l ${root_volume_label} -f"
			else
				rootfs_mkfs_options="-f"
			fi
		fi
		rootfs_install_mount_options="noatime"
		rootfs_mount_options="noatime"
	;;
	*)
		echo "Unknown filesystem specified: ${rootfstype}"
		fail
	;;
esac

# check if we need to install wpasupplicant and crda package
if [ "${ifname}" != "eth0" ]; then
	if [ -z "${syspackages}" ]; then
		syspackages="wpasupplicant,crda"
	else
		syspackages="${syspackages},wpasupplicant,crda"
	fi
fi

# check if we need the sudo package and add it if so
if [ "${userperms_admin}" = "1" ]; then
	if [ -z "${syspackages}" ]; then
		syspackages="sudo"
	else
		syspackages="${syspackages},sudo"
	fi
fi

# determine available releases
mirror_base=http://archive.raspberrypi.org/debian/dists/
release_fallback=bookworm
release_base="${release}"
release_raspbian="${release}"
if ! wget --spider "${mirror_base}/${release}/" &> /dev/null; then
	release_base="${release_fallback}"
fi
if ! wget --spider "${mirror}/dists/${release}/" &> /dev/null; then
	release_raspbian="${release_fallback}"
fi

# if the configuration will install the sysvinit-core package, then the init system will
# be sysvinit, otherwise it will be systemd
if echo "${cdebootstrap_cmdline} ${syspackages} ${packages}" | grep -q "sysvinit-core"; then
	init_system="sysvinit"
	if [ "${use_systemd_services}" != "0" ]; then
		echo "Ignoring 'use_systemd_services' setting because init system is 'sysvinit'"
		use_systemd_services=0
	fi
else
	init_system="systemd"
fi

# configure different kinds of presets
if [ -z "${cdebootstrap_cmdline}" ]; then
	# from small to large: base, minimal, server
	# not very logical that minimal > base, but that's how it was historically defined

	# always add packages if requested or needed
	if [ "${firmware_packages}" = "1" ]; then
		custom_packages_postinstall="${custom_packages_postinstall},firmware-atheros,firmware-brcm80211,firmware-libertas,firmware-misc-nonfree,firmware-realtek"
	fi
	if [ -n "${locales}" ] || [ -n "${system_default_locale}" ]; then
		custom_packages="${custom_packages},locales"
	fi
	if [ -n "${keyboard_layout}" ] && [ "${keyboard_layout}" != "us" ]; then
		custom_packages="${custom_packages},console-setup"
	fi
	if [ "${watchdog_enable}" = "1" ] && [ "${init_system}" != "systemd" ]; then
		custom_packages="${custom_packages},watchdog"
	fi
	if [ "${sound_usb_enable}" = "1" ]; then
		custom_packages_postinstall="${custom_packages_postinstall},alsa-utils,jackd,oss-compat,pulseaudio"
	fi
	# add user defined packages
	if [ -n "${packages}" ]; then
		custom_packages_postinstall="${custom_packages_postinstall},${packages}"
	fi

	# base
	# gnupg is required for 'apt-key' used later in the script
	base_packages="kmod,gnupg"
	base_packages="${custom_packages},${base_packages}"
	if [ "${init_system}" = "systemd" ]; then
		base_packages="${base_packages},libpam-systemd"
	fi
	if [ "${hwrng_support}" = "1" ]; then
		base_packages="${base_packages},rng-tools"
	fi
	if [ "$(find "${tmp_bootfs}"/raspberrypi-ua-netinst/config/apt/ -maxdepth 1 -type f -name "*.list" 2> /dev/null | wc -l)" != 0 ]; then
		base_packages="${base_packages},apt-transport-https"
	fi
	base_packages_postinstall="raspberrypi-bootloader,raspberrypi-kernel"
	base_packages_postinstall="${custom_packages_postinstall},${base_packages_postinstall}"

	# minimal
	minimal_packages="cpufrequtils,openssh-server,dosfstools"
	if [ "${init_system}" != "systemd" ] || [ "${use_systemd_services}" = "0" ]; then
		minimal_packages="${minimal_packages},ntpsec"
		if [ -z "${rtc}" ]; then
			minimal_packages="${minimal_packages},fake-hwclock"
		fi
		minimal_packages="${minimal_packages},ifupdown,net-tools"
	else
		minimal_packages="${minimal_packages},iproute2,systemd-resolved,systemd-timesyncd"
	fi
	minimal_packages_postinstall="${base_packages_postinstall},${minimal_packages_postinstall},raspberrypi-sys-mods"
	if echo "${ifname}" | grep -q "wlan"; then
		minimal_packages_postinstall="${minimal_packages_postinstall},firmware-brcm80211"
	fi

	# server
	server_packages="vim-tiny,iputils-ping,wget,ca-certificates,rsyslog,cron,dialog,locales,tzdata,less,man-db,logrotate,bash-completion,console-setup,apt-utils"
	if [ "${init_system}" = "systemd" ]; then
		server_packages="${server_packages},systemd-sysv"
	fi
	server_packages_postinstall="${minimal_packages_postinstall},${server_packages_postinstall}"
	server_packages_postinstall="${server_packages_postinstall},libraspberrypi-bin"
	if [ "${arch}" != "arm64" ]; then
		server_packages_postinstall="${server_packages_postinstall},raspi-copies-and-fills"
	fi

	# if using base or minimal preset and custom packages include console-setup, keyboard-configuration or tzdata,
	# install them early using cdebootstrap or the initial configuration of keyboard layout or timezone will fail
	if echo "${packages}" | grep -q "console-setup"; then
		base_packages="${base_packages},console-setup"
		minimal_packages="${minimal_packages},console-setup"
	fi
	if echo "${packages}" | grep -q "keyboard-configuration"; then
		base_packages="${base_packages},keyboard-configuration"
		minimal_packages="${minimal_packages},keyboard-configuration"
	fi
	if echo "${packages}" | grep -q "tzdata"; then
		base_packages="${base_packages},tzdata"
		minimal_packages="${minimal_packages},tzdata"
	fi

	# cleanup package variables used by cdebootstrap_cmdline
	variable_sanitize base_packages
	variable_sanitize minimal_packages
	variable_sanitize server_packages
	variable_sanitize syspackages
	case "${preset}" in
		"base")
			cdebootstrap_cmdline="--flavour=minimal --include=${base_packages}"
			packages_postinstall="${base_packages_postinstall}"
			;;
		"minimal")
			cdebootstrap_cmdline="--flavour=minimal --include=${base_packages},${minimal_packages}"
			packages_postinstall="${minimal_packages_postinstall}"
			;;
		*)
			# this should be 'server', but using '*' for backward compatibility
			cdebootstrap_cmdline="--flavour=minimal --include=${base_packages},${minimal_packages},${server_packages}"
			packages_postinstall="${server_packages_postinstall}"
			if [ "${preset}" != "server" ]; then
				echo "Unknown preset specified: ${preset}"
				echo "Using 'server' as fallback"
			fi
			;;
	esac

	# enable cdebootstrap verbose output
	if [ "${cdebootstrap_debug}" = "1" ]; then
		cdebootstrap_cmdline="--verbose --debug ${cdebootstrap_cmdline}";
	fi

	# add user defined syspackages
	if [ -n "${syspackages}" ]; then
		cdebootstrap_cmdline="${cdebootstrap_cmdline},${syspackages}"
	fi

	# add IPv4 DHCP client if needed
	dhcp_client_package="isc-dhcp-client"
	if [ "${ip_addr}" = "dhcp" ]; then
		if echo "${cdebootstrap_cmdline} ${packages_postinstall}" | grep -q "ifupdown"; then
			cdebootstrap_cmdline="${cdebootstrap_cmdline},${dhcp_client_package}"
		fi
	fi

else
	preset=none
fi

if [ "${usbboot}" = "1" ]; then
	if [ "${bootdev}" = "/dev/mmcblk0" ]; then
		echo
		echo "============================================================================================="
		echo "                                  !!! IMPORTANT NOTICE !!!"
		echo "Because you are installing from SD card and want to boot from USB,"
		echo "the system will POWERED OFF after installation."
		echo "After finishing the installation, you must REMOVE the SD card and reboot the system MANUALLY."
		echo
		echo "The installation will continue in 15 seconds..."
		echo "============================================================================================="
		sleep 15s
		final_action=halt
	fi
	bootdev=/dev/sda
	bootpartition=/dev/sda1
fi

if [ -z "${rootpartition}" ]; then
	if [ "${usbroot}" = "1" ]; then
		rootdev=/dev/sda
		if [ "${usbboot}" = "1" ]; then
			rootpartition=/dev/sda2
		else
			rootpartition=/dev/sda1
		fi
	else
		rootpartition=/dev/mmcblk0p2
	fi
fi

# modify variables
# add $system_default_locale to $locales if not included
if [ -n "${system_default_locale}" ]; then
	if ! echo "${locales}" | grep -q "${system_default_locale}"; then
		if [ -z "${locales}" ]; then
			locales="${system_default_locale}"
		else
			locales="${system_default_locale},${locales}"
		fi
	fi
fi

# sanitize_variables
variable_sanitize locales
variable_sanitize packages
variable_sanitize packages_postinstall

# show resulting variables
echo
echo "Resulting installer configuration:"
echo "  preset = ${preset}"
echo "  packages = ${packages}"
echo "  firmware_packages = ${firmware_packages}"
echo "  mirror = ${mirror}"
echo "  mirror_cache = ${mirror_cache}"
echo "  release = ${release_raspbian}"
echo "  arch = ${arch}"
echo "  hostname = ${hostname}"
echo "  domainname = ${domainname}"
echo "  rootpw = ${rootpw}"
echo "  user_ssh_pubkey = ${user_ssh_pubkey}"
echo "  root_ssh_pubkey = ${root_ssh_pubkey}"
echo "  root_ssh_pwlogin = ${root_ssh_pwlogin}"
echo "  ssh_pwlogin = ${ssh_pwlogin}"
echo "  username = ${username}"
echo "  userpw = ${userpw}"
echo "  usergpio = ${usergpio}"
echo "  usergpu = ${usergpu}"
echo "  usergroups = ${usergroups}"
echo "  usersysgroups = ${usersysgroups}"
echo "  userperms_admin = ${userperms_admin}"
echo "  userperms_sound = ${userperms_sound}"
echo "  cdebootstrap_cmdline = ${cdebootstrap_cmdline}"
echo "  cdebootstrap_debug = ${cdebootstrap_debug}"
echo "  packages_postinstall = ${packages_postinstall}"
echo "  boot_volume_label = ${boot_volume_label}"
echo "  root_volume_label = ${root_volume_label}"
echo "  bootsize = ${bootsize}"
echo "  bootoffset = ${bootoffset}"
echo "  rootsize = ${rootsize}"
echo "  timeserver = ${timeserver}"
echo "  timezone = ${timezone}"
echo "  rtc = ${rtc}"
echo "  dt_overlays = ${dt_overlays}"
echo "  keyboard_layout = ${keyboard_layout}"
echo "  locales = ${locales}"
echo "  system_default_locale = ${system_default_locale}"
echo "  wlan_country = ${wlan_country}"
echo "  ip_ipv6 = ${ip_ipv6}"
echo "  cmdline = ${cmdline}"
echo "  drivers_to_load = ${drivers_to_load}"
echo "  gpu_mem = ${gpu_mem}"
echo "  console_blank = ${console_blank}"
echo "  hdmi_type = ${hdmi_type}"
echo "  hdmi_tv_res = ${hdmi_tv_res}"
echo "  hdmi_monitor_res = ${hdmi_monitor_res}"
echo "  hdmi_disable_overscan = ${hdmi_disable_overscan}"
echo "  hdmi_system_only = ${hdmi_system_only}"
echo "  usbroot = ${usbroot}"
echo "  usbboot = ${usbboot}"
echo "  rootdev = ${rootdev}"
echo "  rootpartition = ${rootpartition}"
echo "  rootfstype = ${rootfstype}"
echo "  rootfs_mkfs_options = ${rootfs_mkfs_options}"
echo "  rootfs_install_mount_options = ${rootfs_install_mount_options}"
echo "  rootfs_mount_options = ${rootfs_mount_options}"
echo "  final_action = ${final_action}"
echo "  quiet_boot = ${quiet_boot}"
echo "  disable_raspberries = ${disable_raspberries}"
echo "  disable_splash = ${disable_splash}"
echo "  cleanup = ${cleanup}"
echo "  cleanup_logfiles = ${cleanup_logfiles}"
echo "  spi_enable = ${spi_enable}"
echo "  i2c_enable = ${i2c_enable}"
echo "  i2c_baudrate = ${i2c_baudrate}"
echo "  sound_enable = ${sound_enable}"
echo "  sound_usb_enable = ${sound_usb_enable}"
echo "  sound_usb_first = ${sound_usb_first}"
echo "  camera_enable = ${camera_enable}"
echo "  camera_disable_led = ${camera_disable_led}"
echo "  use_systemd_services = ${use_systemd_services}"
echo
echo "OTP dump:"
vcgencmd otp_dump | grep -v "..:00000000\|..:ffffffff" | sed 's/^/  /'
echo

echo -n "Waiting 5 seconds"
for i in $(seq 1 5); do
	echo -n "."
	sleep 1
done
echo

# fdisk's boot offset is 2048, so only handle $bootoffset is it's larger then that
if [ -n "${bootoffset}" ] && [ "${bootoffset}" -gt 2048 ]; then
	emptyspaceend=$((bootoffset - 1))
else
	emptyspaceend=
fi

# Create a file for partitioning sd card only
FDISK_SCHEME_SD_ONLY=/etc/raspberrypi-ua-netinst/fdisk-sd-only.config
touch "${FDISK_SCHEME_SD_ONLY}"
{
	if [ -n "${emptyspaceend}" ]; then
		# we have a custom bootoffset, so first create a temporary
		# partition occupying the space before it.
		# We'll remove it before committing the changes again.
		echo "n"
		echo "p"
		echo "4"
		echo
		echo "${emptyspaceend}"
	fi
	echo "n"
	echo "p"
	echo "1"
	echo
	echo "${bootsize}"
	echo "t"
	if [ -n "${emptyspaceend}" ]; then
		# because we now have more then 1 partition
		# we need to select the one to operate on
		echo "1"
	fi
	echo "b"
	echo "n"
	echo "p"
	echo "2"
	echo
	echo "${rootsize}"
	if [ -n "${emptyspaceend}" ]; then
		# now remove the temporary partition again
		echo "d"
		echo "4"
	fi
	echo "w"
} >> ${FDISK_SCHEME_SD_ONLY}

# Create a file for partitioning when only /boot/ is on sd card
FDISK_SCHEME_SD_BOOT=/etc/raspberrypi-ua-netinst/fdisk-sd-boot.config
touch "${FDISK_SCHEME_SD_BOOT}"
{
	if [ -n "${emptyspaceend}" ]; then
		# we have a custom bootoffset, so first create a temporary
		# partition occupying the space before it.
		# We'll remove it before committing the changes again.
		echo "n"
		echo "p"
		echo "4"
		echo
		echo "${emptyspaceend}"
	fi
	echo "n"
	echo "p"
	echo "1"
	echo
	echo "${bootsize}"
	echo "t"
	if [ -n "${emptyspaceend}" ]; then
		# because we now have more then 1 partition
		# we need to select the one to operate on
		echo "1"
	fi
	echo "b"
	if [ -n "${emptyspaceend}" ]; then
		# now remove the temporary partition again
		echo "d"
		echo "4"
	fi
	echo "w"
} >> ${FDISK_SCHEME_SD_BOOT}

# Create a file for partitioning when / is on usb
FDISK_SCHEME_USB_ROOT=/etc/raspberrypi-ua-netinst/fdisk-usb-root.config
touch "${FDISK_SCHEME_USB_ROOT}"
{
	echo "n"
	echo "p"
	echo "1"
	echo
	echo "${rootsize}"
	echo "w"
} >> ${FDISK_SCHEME_USB_ROOT}


echo "Waiting for ${rootdev}... "
for i in $(seq 1 10); do
	if fdisk -l "${rootdev}" 2>&1 | grep -F Disk | sed 's/^/  /'; then
		echo "OK"
		break
	fi

	if [ "${i}" -eq 10 ]; then
		echo "FAILED"
		fail
	fi

	sleep 1

	echo -n "${i}.. "
done

if [ "${rootdev}" = "${bootdev}" ]; then
	echo -n "Applying new partition table... "
	dd if=/dev/zero of="${bootdev}" status=none bs=512 count=1
	fdisk "${bootdev}" &> /dev/null < "${FDISK_SCHEME_SD_ONLY}"
	echo "OK"
else
	echo -n "Applying new partition table for ${bootdev}... "
	dd if=/dev/zero of="${bootdev}" status=none bs=512 count=1
	fdisk "${bootdev}" &> /dev/null < "${FDISK_SCHEME_SD_BOOT}"
	echo "OK"

	echo -n "Applying new partition table for ${rootdev}... "
	dd if=/dev/zero of="${rootdev}" status=none bs=512 count=1
	fdisk "${rootdev}" &> /dev/null < "${FDISK_SCHEME_USB_ROOT}"
	echo "OK"
fi

# refresh the /dev device nodes
mdev -s

echo -n "Initializing /boot as vfat... "
if [ -z "${boot_volume_label}" ]; then
	mkfs.vfat -F 32 -s 1 "${bootpartition}" &> /dev/null || fail
else
	mkfs.vfat -F 32 -s 1 -n "${boot_volume_label}" "${bootpartition}" &> /dev/null || fail
fi
echo "OK"

echo -n "Copying /boot files in... "
mount "${bootpartition}" /boot || fail
cp -r "${tmp_bootfs}"/* /boot/ || fail
sync
umount /boot || fail
rm -rf "${tmp_bootfs:?}"/ || fail
echo "OK"

if [ "${kernel_module}" = true ]; then
	if [ "${rootfstype}" != "ext4" ] && [ "${rootfstype}" != "f2fs" ]; then
		echo -n "Loading ${rootfstype} module... "
		modprobe "${rootfstype}" &> /dev/null || fail
		echo "OK"
	fi
fi


echo -n "Initializing / as ${rootfstype}... "
eval mkfs."${rootfstype}" "${rootfs_mkfs_options}" "${rootpartition}" | sed 's/^/  /'
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
	fail
fi
echo "OK"

echo -n "Mounting new filesystems... "
mount "${rootpartition}" /rootfs -o "${rootfs_install_mount_options}" || fail
mkdir /rootfs/boot || fail
mount "${bootpartition}" /rootfs/boot || fail
echo "OK"

# use 256MB file based swap during installation if needed
if [ "$(free -m | awk '/^Mem:/{print $2}')" -lt "384" ]; then
	echo -n "Creating temporary swap file... "
	dd if=/dev/zero of="${installer_swapfile}" status=none bs=4096 count=65536 || fail
	chmod 600 "${installer_swapfile}"
	mkswap "${installer_swapfile}" > /dev/null
	swapon "${installer_swapfile}" || fail
	echo "OK"
fi

echo -n "Starting HWRNG... "
if /usr/sbin/rngd -r /dev/hwrng; then
	echo "OK"
else
	echo "FAILED! (continuing to use the software RNG)"
fi

if [ "${kernel_module}" = true ]; then
	if [ "${rootfstype}" != "ext4" ] && [ "${rootfstype}" != "f2fs" ]; then
		mkdir -p /rootfs/etc/initramfs-tools
		echo "${rootfstype}" >> /rootfs/etc/initramfs-tools/modules
	fi
fi

echo
echo "Starting install process..."
for i in $(seq 1 "${installer_pkg_downloadretries}"); do
	if [ -n "${mirror_cache}" ]; then
		export http_proxy="http://${mirror_cache}/"
	fi
	if [ "${arch}" = "arm64" ]; then
		keyring="debian-archive-keyring.gpg"
	else
		keyring="raspbian-archive-keyring.gpg"
	fi
	eval cdebootstrap-static --arch="${arch}" "${cdebootstrap_cmdline}" "${release_raspbian}" /rootfs "${mirror}" --keyring=/usr/share/keyrings/${keyring} 2>&1 | output_filter
	cdebootstrap_exitcode="${PIPESTATUS[0]}"
	if [ "${cdebootstrap_exitcode}" -eq 0 ]; then
		unset http_proxy
		break
	else
		unset http_proxy
		if [ "${i}" -eq "${installer_pkg_downloadretries}" ]; then
			echo -e "\n  ERROR: ${cdebootstrap_exitcode}"
			fail
		else
			echo -e "\n  ERROR: ${cdebootstrap_exitcode}, trying again ($((i+1))/${installer_pkg_downloadretries})..."
		fi
	fi
done
echo "OK"

echo
echo "Configuring installed system:"
# mount chroot system folders
for sysfolder in /dev /dev/pts /proc /sys; do
	mount --bind "${sysfolder}" "/rootfs${sysfolder}"
done
# set init system
if [ "${init_system}" = "systemd" ] && [ ! -f /rootfs/sbin/init ] && [ ! -h /rootfs/sbin/init ]; then
	ln -s /lib/systemd/systemd /rootfs/sbin/init
fi

# configure root login
if [ -n "${rootpw}" ]; then
	echo -n "  Setting root password... "
	echo -n "root:${rootpw}" | chroot /rootfs /usr/sbin/chpasswd || fail
	echo "OK"
fi
# add SSH key for root (if provided)
if [ -n "${root_ssh_pubkey}" ]; then
	echo -n "  Setting root SSH key"
	if mkdir -p /rootfs/root/.ssh && chmod 700 /rootfs/root/.ssh; then
		if [ -f "/rootfs/boot/raspberrypi-ua-netinst/config/files/${root_ssh_pubkey}" ]; then
			echo -n " from file '${root_ssh_pubkey}'... "
			cp "/rootfs/boot/raspberrypi-ua-netinst/config/files/${root_ssh_pubkey}" /rootfs/root/.ssh/authorized_keys || fail
			echo "OK"
		else
			echo -n "... "
			echo "${root_ssh_pubkey}" > /rootfs/root/.ssh/authorized_keys
		fi
		echo -n "  Setting permissions on root SSH authorized_keys... "
		chmod 600 /rootfs/root/.ssh/authorized_keys || fail
		echo "OK"
	else
		echo -n "... "
		fail
	fi
fi
# openssh-server doesn't allow root to login with a password
if [ "${root_ssh_pwlogin}" = "1" ]; then
	if [ -f /rootfs/etc/ssh/sshd_config ]; then
		echo -n "  Allowing root to login with password... "
		sed -i '/PermitRootLogin/s/.*/PermitRootLogin yes/' /rootfs/etc/ssh/sshd_config || fail
		echo "OK"
	fi
fi
# disable global password login if requested
if [ "${ssh_pwlogin}" = "0" ]; then
	if [ -f /rootfs/etc/ssh/sshd_config ]; then
		echo -n "  Disabling SSH password login for users... "
		sed -i "s/^\(#\)*\(PasswordAuthentication \)\S\+/\2no/" /rootfs/etc/ssh/sshd_config || fail
		echo "OK"
	fi
fi

# add basic system groups
chroot /rootfs /usr/sbin/groupadd -fr gpio || fail

# add user to system
if [ -n "${username}" ]; then
	echo "  Configuring user '${username}':"
	chroot /rootfs /usr/sbin/adduser "${username}" --gecos "" --disabled-password | sed 's/^/    /'
	if [ "${PIPESTATUS[0]}" -ne 0 ]; then
		fail
	fi
	# add SSH key for user (if provided)
	if [ -n "${user_ssh_pubkey}" ]; then
		echo -n "  Setting SSH key for '${username}'"
		if mkdir -p "/rootfs/home/${username}/.ssh" && chmod 700 "/rootfs/home/${username}/.ssh"; then
			if [ -f "/rootfs/boot/raspberrypi-ua-netinst/config/files/${user_ssh_pubkey}" ]; then
				echo -n " from file '${user_ssh_pubkey}'... "
				cp "/rootfs/boot/raspberrypi-ua-netinst/config/files/${user_ssh_pubkey}" "/rootfs/home/${username}/.ssh/authorized_keys" || fail
				echo "OK"
			else
				echo -n "... "
				echo "${user_ssh_pubkey}" > "/rootfs/home/${username}/.ssh/authorized_keys"
				echo "OK"
			fi
			echo -n "  Setting owner as '${username}' on SSH directory... "
			chroot /rootfs /bin/chown -R "${username}:${username}" "/home/${username}/.ssh" || fail
			echo "OK"
			echo -n "  Setting permissions on '${username}' SSH authorized_keys... "
			chmod 600 "/rootfs/home/${username}/.ssh/authorized_keys" || fail
			echo "OK"
		else
			echo -n "... "
			fail
		fi
	fi
	if [ -n "${userpw}" ]; then
		echo -n "  Setting password for '${username}'... "
		echo -n "${username}:${userpw}" | chroot /rootfs /usr/sbin/chpasswd || fail
		echo "OK"
	fi
	if [ "${usergpio}" = "1" ]; then
		usersysgroups="${usersysgroups},gpio"
	fi
	if [ "${userperms_sound}" = "1" ]; then
		usersysgroups="${usersysgroups},audio"
	fi
	if [ "${usergpu}" = "1" ]; then
		usersysgroups="${usersysgroups},video"
	fi
	if [ -n "${usersysgroups}" ]; then
		echo -n "  Adding '${username}' to system groups: "
		convert_listvariable usersysgroups
		for sysgroup in ${usersysgroups}; do
			echo -n "${sysgroup}... "
			chroot /rootfs /usr/sbin/groupadd -fr "${sysgroup}" || fail
			chroot /rootfs /usr/sbin/usermod -aG "${sysgroup}" "${username}" || fail
		done
		echo "OK"
	fi
	if [ -n "${usergroups}" ]; then
		echo -n "  Adding '${username}' to groups: "
		convert_listvariable usergroups
		for usergroup in ${usergroups}; do
			echo -n "${usergroup} "
			chroot /rootfs /usr/sbin/groupadd -f "${usergroup}" || fail
			chroot /rootfs /usr/sbin/usermod -aG "${usergroup}" "${username}" || fail
		done
		echo "OK"
	fi
	if [ "${userperms_admin}" = "1" ]; then
		echo -n "  Adding '${username}' to sudo group... "
		chroot /rootfs /usr/sbin/usermod -aG sudo "${username}" || fail
		echo "OK"
		if [ -z "${userpw}" ]; then
			echo -n "  Setting '${username}' to sudo without a password... "
			echo -n "${username} ALL = (ALL) NOPASSWD: ALL" > "/rootfs/etc/sudoers.d/${username}" || fail
			chmod 440 "/rootfs/etc/sudoers.d/${username}" || fail
			echo "OK"
		fi
	fi
fi

bootpartition_uuid=PARTUUID=$(blkid -o value -s PARTUUID ${bootpartition})
rootpartition_uuid=PARTUUID=$(blkid -o value -s PARTUUID ${rootpartition})

# default mounts
echo -n "  Configuring /etc/fstab... "
touch /rootfs/etc/fstab || fail
{
	echo "${bootpartition_uuid} /boot vfat defaults 0 2"
	if [ "${rootfstype}" = "f2fs" ]; then
		echo "${rootpartition_uuid} / ${rootfstype} ${rootfs_mount_options} 0 0"
	elif [ "${rootfstype}" = "btrfs" ]; then
		echo "${rootpartition_uuid} / ${rootfstype} ${rootfs_mount_options} 0 0"
	else
		echo "${rootpartition_uuid} / ${rootfstype} ${rootfs_mount_options} 0 1"
	fi
	# also specify /tmp on tmpfs in /etc/fstab so it works across init systems
	echo "tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0"
} >> /rootfs/etc/fstab || fail
echo "OK"

# default hostname
echo -n "  Configuring hostname... "
echo "${hostname}" > /rootfs/etc/hostname || fail
echo "OK"

echo -n "  Configuring hosts... "
touch /rootfs/etc/hosts
# Add localhost to hosts (if needed)
if ! grep -q "localhost" /rootfs/etc/hosts; then
	echo -n "adding localhost... "
	echo "127.0.0.1 localhost" >> /rootfs/etc/hosts || fail
fi
# Remove any existing 127.0.1.1 entries
sed -i 's/^.*127\.0\.1\.1.*$//' /rootfs/etc/hosts
# Create the 127.0.1.1 entry
if [ -z "${domainname}" ]; then
	echo -n "adding ${hostname}... "
	echo "127.0.1.1 ${hostname}" >> /rootfs/etc/hosts || fail
else
	echo -n "adding ${hostname}.${domainname}... "
	echo "127.0.1.1 ${hostname}.${domainname} ${hostname}" >> /rootfs/etc/hosts || fail
fi
echo "OK"

# networking - ifupdown
if echo "${cdebootstrap_cmdline} ${packages_postinstall}" | grep -q "ifupdown"; then
	echo -n "  Configuring ifupdown network settings... "
	mkdir -p /rootfs/etc/network
	touch /rootfs/etc/network/interfaces || fail
	# lo interface may already be there, so first check for it
	if ! grep -q "auto lo" /rootfs/etc/network/interfaces; then
		echo "auto lo" >> /rootfs/etc/network/interfaces
		echo "iface lo inet loopback" >> /rootfs/etc/network/interfaces
	fi

	# configured interface
	echo >> /rootfs/etc/network/interfaces
	echo "allow-hotplug ${ifname}" >> /rootfs/etc/network/interfaces
	if [ "${ip_addr}" = "dhcp" ]; then
		echo "iface ${ifname} inet dhcp" >> /rootfs/etc/network/interfaces
	else
		{
			echo "iface ${ifname} inet static"
			echo "    address ${ip_addr}"
			echo "    netmask ${ip_netmask}"
			echo "    broadcast ${ip_broadcast}"
			echo "    gateway ${ip_gateway}"
		} >> /rootfs/etc/network/interfaces
	fi

	# wlan config
	if echo "${ifname}" | grep -q "wlan"; then
		if [ -e "${wlan_configfile}" ]; then
			# copy the installer version of `wpa_supplicant.conf`
			mkdir -p /rootfs/etc/wpa_supplicant
			cp "${wlan_configfile}" /rootfs/etc/wpa_supplicant/
			chmod 600 /rootfs/etc/wpa_supplicant/wpa_supplicant.conf
			echo "    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf" >> /rootfs/etc/network/interfaces
		fi
		{
			echo
			echo "allow-hotplug eth0"
			echo "iface eth0 inet dhcp"
		} >> /rootfs/etc/network/interfaces
	fi

	echo "OK"

	# copy resolv.conf
	echo -n "  Configuring nameserver... "
	if [ -e "/etc/resolv.conf" ]; then
		if cp /etc/resolv.conf /rootfs/etc/; then
			echo "OK"
		else
			echo "FAILED !"
			fail
		fi
	else
		echo "MISSING !"
		fail
	fi
fi

# networking - systemd
if [ "${use_systemd_services}" != "0" ]; then
	echo -n "  Configuring systemd network settings... "
	NETFILE=/rootfs/etc/systemd/network/primary.network
	mkdir -p /rootfs/etc/systemd/network

	{
		echo "[Match]"
		echo "Name=${ifname}"
		echo "[Network]"
	} >> ${NETFILE}

	if [ "${ip_addr}" = "dhcp" ]; then
		echo "DHCP=yes" >> ${NETFILE}
	else
		NETPREFIX=$(/bin/busybox ipcalc -p "${ip_addr}" "${ip_netmask}" | cut -f2 -d=)
		{
			echo "Address=${ip_addr}/${NETPREFIX}"
			for i in ${ip_nameservers}; do
				echo "DNS=${i}"
			done
			if [ -n "${timeserver}" ]; then
				echo "NTP=${timeserver}"
			fi
			echo "[Route]"
			echo "Gateway=${ip_gateway}"
		} >> ${NETFILE}
	fi

	# enable systemd-networkd service
	ln -s /lib/systemd/system/systemd-networkd.service /rootfs/etc/systemd/system/multi-user.target.wants/systemd-networkd.service

	# enable systemd-resolved service
	ln -s /lib/systemd/system/systemd-resolved.service /rootfs/etc/systemd/system/multi-user.target.wants/systemd-resolved.service

	# wlan config
	if echo "${ifname}" | grep -q "wlan"; then
		if [ -e "${wlan_configfile}" ]; then
			# copy the installer version of `wpa_supplicant.conf`
			mkdir -p /rootfs/etc/wpa_supplicant
			cp "${wlan_configfile}" "/rootfs/etc/wpa_supplicant/wpa_supplicant-${ifname}.conf"
			chmod 600 "/rootfs/etc/wpa_supplicant/wpa_supplicant-${ifname}.conf"
		fi
		# enable wpa_supplicant service
		ln -s /lib/systemd/system/wpa_supplicant@.service "/rootfs/etc/systemd/system/multi-user.target.wants/wpa_supplicant@${ifname}.service"
		rm /rootfs/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service
	fi

	echo "OK"
fi

# Mask udev link files if predictable network interface names are not desired
if [ "${disable_predictable_nin}" = "1" ]; then
	# as described here: https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames
	# masking 99-default.link and also 73-usb-net-by-mac.link (as raspi-config does)
	ln -s /dev/null /rootfs/etc/systemd/network/99-default.link
	ln -s /dev/null /rootfs/etc/systemd/network/73-usb-net-by-mac.link
fi

# set timezone and reconfigure tzdata package
if [ -n "${timezone}" ]; then
	echo -n "  Configuring tzdata (timezone \"${timezone}\")... "
	if [ -e "/rootfs/usr/share/zoneinfo/${timezone}" ]; then
		ln -sf "/usr/share/zoneinfo/${timezone}" /rootfs/etc/localtime
		if chroot /rootfs /usr/sbin/dpkg-reconfigure -f noninteractive tzdata &> /dev/null; then
			echo "OK"
		else
			echo "FAILED !"
		fi
	else
		echo "INVALID !"
	fi
fi

# generate locale data
if [ -n "${locales}" ]; then
	echo -n "  Enabling locales... "
	convert_listvariable locales
	for locale in ${locales}; do
		echo -n "${locale}... "
		locale_regex="${locale//./\.}" # escape dots
		if [ -f /rootfs/etc/locale.gen ] && [ "$(grep -c "^# ${locale_regex}" /rootfs/etc/locale.gen)" -gt 0 ]; then
			# Accept UTF-8 by using "xx_XX.UTF-8"
			if [ "$(grep -c "^# ${locale_regex} UTF-8" /rootfs/etc/locale.gen)" -eq 1 ]; then
				sed -i "s/^# \(${locale_regex} UTF-8\)/\1/" /rootfs/etc/locale.gen
			# Accept UTF-8 by using "xx_XX"
			elif [ "$(grep -c "^# ${locale_regex}\.UTF-8 UTF-8" /rootfs/etc/locale.gen)" -eq 1 ]; then
				sed -i "s/^# \(${locale_regex}\.UTF-8 UTF-8\)/\1/" /rootfs/etc/locale.gen
			# Accept other by using "xx_XX.XXX"
			elif [ "$(grep -c "^# ${locale_regex} " /rootfs/etc/locale.gen)" -eq 1 ]; then
				sed -i "s/^# \(${locale_regex} \)/\1/" /rootfs/etc/locale.gen
			else
				echo -n "NOT unique... "
			fi
		else
			echo -n "NOT found... "
		fi
		unset locale_regex
	done
	echo "OK"
	if [ -x /rootfs/usr/sbin/locale-gen ]; then
		chroot /rootfs /usr/sbin/locale-gen | sed 's/^/  /'
		if [ "${PIPESTATUS[0]}" -ne 0 ]; then
			echo "  ERROR while generating locales !"
		fi
	fi
fi

# set system default locale
if [ -n "${system_default_locale}" ]; then
	if [ -x /rootfs/usr/sbin/update-locale ]; then
		echo -n "  Setting system default locale "
		system_default_locale_regex="${system_default_locale//./\.}" # escape dots
		if [ -f /rootfs/etc/locale.gen ] && [ "$(grep -c "^${system_default_locale_regex}" /rootfs/etc/locale.gen)" -gt 0 ]; then
			# Accept UTF-8 by using "xx_XX.UTF-8"
			if [ "$(grep -c "^${system_default_locale_regex} UTF-8" /rootfs/etc/locale.gen)" -eq 1 ]; then
				system_default_locale="$(grep "^${system_default_locale_regex} UTF-8" /rootfs/etc/locale.gen)"
			# Accept UTF-8 by using "xx_XX"
			elif [ "$(grep -c "^${system_default_locale_regex}\.UTF-8 UTF-8" /rootfs/etc/locale.gen)" -eq 1 ]; then
				system_default_locale="$(grep "^${system_default_locale_regex}\.UTF-8 UTF-8" /rootfs/etc/locale.gen)"
			# Accept other by using "xx_XX.XXX"
			elif [ "$(grep -c "^${system_default_locale_regex} " /rootfs/etc/locale.gen)" -eq 1 ]; then
				system_default_locale="$(grep "^${system_default_locale_regex} " /rootfs/etc/locale.gen)"
			else
				echo "skipped because \"${system_default_locale}\" NOT unique !"
				unset system_default_locale
			fi
			if [ -n "${system_default_locale}" ]; then
				system_default_locale="$(echo "${system_default_locale}" | grep -Eo "^\S+")" # trim to first space character
				echo -n "'${system_default_locale}'... "
				if chroot /rootfs /usr/sbin/update-locale LANG="${system_default_locale}" &> /dev/null; then
					echo "OK"
				else
					echo "FAILED !"
				fi
			fi
		else
			echo "skipped because \"${system_default_locale}\" NOT found !"
			unset system_default_locale
		fi
		unset system_default_locale_regex
	fi
fi

# set keyboard layout
keyboard_layouts=("af" "al" "am" "ara" "at" "az" "ba" "bd" "be" "bg" "br" "brai" "bt" "bw" "by" "ca" "cd" "ch" "cm" "cn" "cz" "de" \
	"dk" "ee" "epo" "es" "et" "fi" "fo" "fr" "gb" "ge" "gh" "gn" "gr" "hr" "hu" "ie" "il" "in" "iq" "ir" "is" "it" "jp" "ke" "kg" \
	"kh" "kr" "kz" "la" "latam" "lk" "lt" "lv" "ma" "mao" "md" "me" "mk" "ml" "mm" "mn" "mt" "mv" "nec_vndr/jp" "ng" "nl" "no" "np" \
	"ph" "pk" "pl" "pt" "ro" "rs" "ru" "se" "si" "sk" "sn" "sy" "th" "tj" "tm" "tr" "tw" "tz" "ua" "us" "uz" "vn" "za" "NA")
if [ -n "${keyboard_layout}" ]; then
	echo -n "  Setting default keyboard layout '${keyboard_layout}'... "
	for layout in "${keyboard_layouts[@]}"; do
		if [ "${layout}" = "${keyboard_layout}" ]; then
			sed -i "s/^\(XKBLAYOUT=\).*/\1\"${keyboard_layout}\"/" /rootfs/etc/default/keyboard
			echo "OK"
			break
		elif [ "${layout}" = "NA" ]; then
			echo "NOT found !"
		fi
	done
fi

echo

if [ "${use_systemd_services}" = "0" ]; then
	# if systemd is not in use, setup hwclock appropriately
	if [ -z "${rtc}" ]; then
		if grep -q "#HWCLOCKACCESS=yes" /rootfs/etc/default/hwclock; then
			sed -i "s/^#\(HWCLOCKACCESS=\)yes/\1no/" /rootfs/etc/default/hwclock
		elif grep -q "HWCLOCKACCESS=yes" /rootfs/etc/default/hwclock; then
			sed -i "s/^\(HWCLOCKACCESS=\)yes/\1no/m" /rootfs/etc/default/hwclock
		else
			echo -e "HWCLOCKACCESS=no\n" >> /rootfs/etc/default/hwclock
		fi
	else
		sed -i "s/^\(exit 0\)/\/sbin\/hwclock --hctosys\n\1/" /rootfs/etc/rc.local
	fi
else
	ln -s /lib/systemd/system/systemd-timesyncd.service /rootfs/etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service

	if [ -n "${rtc}" ]; then
		cat > /rootfs/etc/systemd/system/hwclock-to-sysclock.service << EOF
[Unit]
Description=Set system clock from hardware clock
After=systemd-modules-load.service

[Service]
Type=oneshot
ExecStart=/sbin/hwclock --hctosys --utc

[Install]
WantedBy=basic.target

EOF
		mkdir /rootfs/etc/systemd/system/basic.target.wants
		ln -s /etc/systemd/system/hwclock-to-sysclock.service /rootfs/etc/systemd/system/basic.target.wants/hwclock-to-sysclock.service
	fi
fi

# copy apt's sources.list to the target system
echo "Configuring apt:"
echo -n "  Configuring Raspbian/Debian repository... "
if [ -e "/rootfs/boot/raspberrypi-ua-netinst/config/apt/sources.list" ]; then
	sed "s/__RELEASE__/${release_raspbian}/g" "/rootfs/boot/raspberrypi-ua-netinst/config/apt/sources.list" > "/rootfs/etc/apt/sources.list" || fail
else
	if [ "${arch}" = "arm64" ]; then
		echo "deb ${mirror} ${release_raspbian} main contrib non-free" > "/rootfs/etc/apt/sources.list" || fail
		echo "deb http://security.debian.org/debian-security ${release_raspbian}-security main contrib non-free" >> "/rootfs/etc/apt/sources.list" || fail
		echo "deb ${mirror} ${release_raspbian}-updates main contrib non-free" >> "/rootfs/etc/apt/sources.list" || fail
	else
		echo "deb ${mirror} ${release_raspbian} main contrib non-free firmware" > "/rootfs/etc/apt/sources.list" || fail
	fi
fi
echo "OK"
# if __RELEASE__ is still present, something went wrong
echo -n "  Checking Raspbian/Debian repository entry... "
if grep -l '__RELEASE__' /rootfs/etc/apt/sources.list > /dev/null; then
	fail
else
	echo "OK"
fi
echo -n "  Checking Raspbian/Debian GPG key... "
if [ "$(chroot /rootfs /usr/bin/gpg --keyring "/usr/share/keyrings/raspbian-archive-keyring.gpg" --with-colons --fingerprint 2> /dev/null)" == \
     "$(chroot /rootfs /usr/bin/gpg --keyring "/etc/apt/trusted.gpg" --with-colons --fingerprint 2> /dev/null)" ]; then
	# deprecated apt-key usage detected; remove legacy trusted.gpg keyring
	echo -n "Moving key to /etc/apt/trusted.gpg.d/... "
	(chroot /rootfs install -m 644 "/usr/share/keyrings/raspbian-archive-keyring.gpg" "/etc/apt/trusted.gpg.d/") || fail
	rm "/rootfs/etc/apt/trusted.gpg" || fail
fi
echo "OK"

echo -n "  Adding raspberrypi.org GPG key to /etc/apt/trusted.gpg.d/... "
raspberrypi_gpg="/rootfs/etc/apt/trusted.gpg.d/raspberrypi.gpg"
(chroot /rootfs /usr/bin/gpg --dearmor - > "$raspberrypi_gpg") < /usr/share/keyrings/raspberrypi.gpg.key || fail
chmod 644 "$raspberrypi_gpg" || fail
echo "OK"

echo -n "  Configuring RaspberryPi repository... "
if [ -e "/rootfs/boot/raspberrypi-ua-netinst/config/apt/raspberrypi.org.list" ]; then
	sed "s/__RELEASE__/${release_base}/g" "/rootfs/boot/raspberrypi-ua-netinst/config/apt/raspberrypi.org.list" > "/rootfs/etc/apt/sources.list.d/raspberrypi.org.list" || fail
else
	sed "s/__RELEASE__/${release_base}/g" "/opt/raspberrypi-ua-netinst/res/etc/apt/raspberrypi.org.list" > "/rootfs/etc/apt/sources.list.d/raspberrypi.org.list" || fail
fi
echo "OK"
echo -n "  Configuring RaspberryPi preference... "
if [ -e "/rootfs/boot/raspberrypi-ua-netinst/config/apt/archive_raspberrypi_org.pref" ]; then
	sed "s/__RELEASE__/${release_base}/g" "/rootfs/boot/raspberrypi-ua-netinst/config/apt/archive_raspberrypi_org.pref" > "/rootfs/etc/apt/preferences.d/archive_raspberrypi_org.pref" || fail
else
	sed "s/__RELEASE__/${release_base}/g" "/opt/raspberrypi-ua-netinst/res/etc/apt/archive_raspberrypi_org.pref" > "/rootfs/etc/apt/preferences.d/archive_raspberrypi_org.pref" || fail
fi
echo "OK"

# save the current location so that we can go back to it later on
old_dir=$(pwd)
cd /rootfs/boot/raspberrypi-ua-netinst/config/apt/ || fail

# iterate through all the *.list files and add them to /etc/apt/sources.list.d
for listfile in ./*.list
do
	if [ "${listfile}" != "./sources.list" ] && [ "${listfile}" != "./raspberrypi.org.list" ] && [ -e "${listfile}" ]; then
		echo -n "  Copying '${listfile}' to /etc/apt/sources.list.d/... "
		sed "s/__RELEASE__/${release_raspbian}/g" "${listfile}" > "/rootfs/etc/apt/sources.list.d/${listfile}" || fail
		echo "OK"
	fi
done

# iterate through all the *.pref files and add them to /etc/apt/preferences.d
for preffile in ./*.pref
do
	if [ "${preffile}" != "./archive_raspberrypi_org.pref" ] && [ -e "${preffile}" ]; then
		echo -n "  Copying '${preffile}' to /etc/apt/preferences.d/... "
		sed "s/__RELEASE__/${release_raspbian}/g" "${preffile}" > "/rootfs/etc/apt/preferences.d/${preffile}" || fail
		echo "OK"
	fi
done

# iterate through all the *.key files and add them to apt-key
for keyfile in ./*.key
do
	if [ -e "${keyfile}" ]; then
		echo "  Adding key '${keyfile}' to apt..."
		(chroot /rootfs /usr/bin/apt-key add - 2>&1) < "${keyfile}" | sed 's/^/    /'
		if [ "${PIPESTATUS[0]}" -ne 0 ]; then
			fail
		fi
		echo "OK"
	fi
done

# iterate through all the *.gpg files and add them to /etc/apt/trusted.gpg.d
for keyring in ./*.gpg
do
	if [ -e "${keyring}" ]; then
		echo -n "  Copying '${keyring}' to /etc/apt/trusted.gpg.d/... "
		cp "${keyring}" "/rootfs/etc/apt/trusted.gpg.d/${keyring}" || fail
		echo "OK"
	fi
done

# iterate through all the *.conf files and add them to /etc/apt/apt.conf.d
for conffile in ./*.conf
do
	if [ -e "${conffile}" ]; then
		echo -n "  Copying '${conffile%.*}' to /etc/apt/apt.conf.d/... "
		sed "s/__RELEASE__/${release_raspbian}/g" "${conffile}" > "/rootfs/etc/apt/apt.conf.d/${conffile%.*}" || fail
		echo "OK"
	fi
done

# return to the old location for the rest of the processing
cd "${old_dir}" || fail

echo
echo -n "Updating package lists... "
for i in $(seq 1 "${installer_pkg_updateretries}"); do
	if [ -z "${mirror_cache}" ]; then
		chroot /rootfs /usr/bin/apt-get update &> /dev/null
	else
		chroot /rootfs /usr/bin/apt-get -o Acquire::http::Proxy=http://"${mirror_cache}" update &> /dev/null
	fi
	update_exitcode="${?}"
	if [ "${update_exitcode}" -eq 0 ]; then
		echo "OK"
		break
	elif [ "${i}" -eq "${installer_pkg_updateretries}" ]; then
		echo "ERROR: ${update_exitcode}, FAILED !"
		fail
	else
		echo -n "ERROR: ${update_exitcode}, trying again ($((i+1))/${installer_pkg_updateretries})... "
	fi
done

# kernel and firmware package can't be installed during cdebootstrap phase, so do so now
if [ -n "${packages_postinstall}" ]; then
	convert_listvariable packages_postinstall
fi

DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

echo
echo "Downloading packages..."
for i in $(seq 1 "${installer_pkg_downloadretries}"); do
	if [ -z "${mirror_cache}" ]; then
		eval chroot /rootfs /usr/bin/apt-get -y -d upgrade "${packages_postinstall}" 2>&1 | output_filter
	else
		eval chroot /rootfs /usr/bin/apt-get -o Acquire::http::Proxy=http://"${mirror_cache}" -y -d upgrade "${packages_postinstall}" 2>&1 | output_filter
	fi
	download_exitcode="${PIPESTATUS[0]}"
	if [ "${download_exitcode}" -eq 0 ]; then
		echo "OK"
		break
	elif [ "${i}" -eq "${installer_pkg_downloadretries}" ]; then
		echo "ERROR: ${download_exitcode}, FAILED !"
		fail
	else
		echo -n "ERROR: ${download_exitcode}, trying again ($((i+1))/${installer_pkg_downloadretries})... "
	fi
done

echo
echo "Installing kernel, bootloader (=firmware) and user packages..."
eval chroot /rootfs /usr/bin/apt-get -y upgrade "${packages_postinstall}" 2>&1 | output_filter
if [ "${PIPESTATUS[0]}" -eq 0 ]; then
	echo "OK"
else
	echo "FAILED !"
fi

unset DEBIAN_FRONTEND
echo

# remove cdebootstrap-helper-rc.d which prevents rc.d scripts from running
echo -n "Removing cdebootstrap-helper-rc.d... "
chroot /rootfs /usr/bin/dpkg -r cdebootstrap-helper-rc.d &> /dev/null || fail
echo "OK"

echo -n "Configuring bootloader to start the installed system..."
if [ -e "/rootfs/boot/raspberrypi-ua-netinst/config/boot/config.txt" ]; then
	cp /rootfs/boot/raspberrypi-ua-netinst/config/boot/config.txt /rootfs/boot/config.txt
else
	cp /opt/raspberrypi-ua-netinst/res/boot/config.txt /rootfs/boot/config.txt
fi
if [ -n "$(tail -c1 /rootfs/boot/config.txt)" ]; then
	echo >> /rootfs/boot/config.txt
fi

# extend device initialization time when booting from usb
if [ "${usbboot}" = "1" ]; then
	touch /rootfs/boot/TIMEOUT
fi
echo "OK"

# create cmdline.txt
echo -n "Creating cmdline.txt... "
line_add cmdline "root=${rootpartition_uuid} rootfstype=${rootfstype} rootwait"
line_add_if_boolean quiet_boot cmdline_custom "quiet" "loglevel=3"
line_add_if_boolean disable_raspberries cmdline_custom "logo.nologo"
line_add_if_set console_blank cmdline_custom "consoleblank=${console_blank}"
line_add_if_boolean_not ip_ipv6 cmdline_custom "ipv6.disable=1"
line_add_if_set cmdline_custom cmdline "${cmdline_custom}"
echo "${cmdline}" > /rootfs/boot/cmdline.txt
echo "OK"

# Password warning
if [ -f /rootfs/etc/profile.d/sshpasswd.sh ]; then
	echo -n "Fixing non-privileged SSH password warning... "
	sed -i "s/service ssh status/\/usr\/sbin\/service ssh status/" /rootfs/etc/profile.d/sshpasswd.sh
	echo "OK"
fi

# enable spi if specified in the configuration file
if [ "${spi_enable}" = "1" ]; then
	if [ "$(grep -c "^dtparam=spi=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
	sed -i "s/^#\(dtparam=spi=on\)/\1/" /rootfs/boot/config.txt
		sed -i "s/^\(dtparam=spi=.*\)/#\1/" /rootfs/boot/config.txt
		echo "dtparam=spi=on" >> /rootfs/boot/config.txt
	fi
fi

# enable i2c if specified in the configuration file
if [ "${i2c_enable}" = "1" ]; then
	sed -i "s/^#\(dtparam=i2c_arm=on\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^dtparam=i2c_arm=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
		sed -i "s/^\(dtparam=i2c_arm=.*\)/#\1/" /rootfs/boot/config.txt
		echo "dtparam=i2c_arm=on" >> /rootfs/boot/config.txt
	fi
	module_enable "i2c-dev" "i2c"
	if [ -n "${i2c_baudrate}" ]; then
		if grep -q "i2c_baudrate=" /rootfs/boot/config.txt; then
			sed -i "s/\(.*i2c_baudrate=.*\)/#\1/" /rootfs/boot/config.txt
		fi
		if grep -q "i2c_arm_baudrate=" /rootfs/boot/config.txt; then
			sed -i "s/\(.*i2c_arm_baudrate=.*\)/#\1/" /rootfs/boot/config.txt
		fi
		sed -i "s/^#\(dtparam=i2c_arm_baudrate=${i2c_baudrate}\)/\1/" /rootfs/boot/config.txt
		if [ "$(grep -c "^dtparam=i2c_arm_baudrate=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
			sed -i "s/^\(dtparam=i2c_arm_baudrate=.*\)/#\1/" /rootfs/boot/config.txt
			echo "dtparam=i2c_arm_baudrate=${i2c_baudrate}" >> /rootfs/boot/config.txt
		fi
	fi
fi

# enable sound if specified in the configuration file
if [ "${sound_enable}" = "1" ]; then
	sed -i "s/^#\(dtparam=audio=on\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^dtparam=audio=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
		sed -i "s/^\(dtparam=audio=.*\)/#\1/" /rootfs/boot/config.txt
		echo "dtparam=audio=on" >> /rootfs/boot/config.txt
	fi
fi

# enable camera if specified in the configuration file
if [ "${camera_enable}" = "1" ]; then
	if [ "0${gpu_mem}" -lt "128" ]; then
		gpu_mem=128
	fi
	sed -i "s/^#\(start_x=1\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^start_x=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
		sed -i "s/^\(start_x=.*\)/#\1/" /rootfs/boot/config.txt
		echo "start_x=1" >> /rootfs/boot/config.txt
	fi
	if [ "${camera_disable_led}" = "1" ]; then
		sed -i "s/^#\(disable_camera_led=1\)/\1/" /rootfs/boot/config.txt
		if [ "$(grep -c "^disable_camera_led=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
			sed -i "s/^\(disable_camera_led=.*\)/#\1/" /rootfs/boot/config.txt
			echo "disable_camera_led=1" >> /rootfs/boot/config.txt
		fi
	fi
fi

# set gpu_mem if specified in the configuration file
if [ -n "${gpu_mem}" ]; then
	sed -i "s/^#\(gpu_mem=${gpu_mem}\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^gpu_mem=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
		sed -i "s/^\(gpu_mem=.*\)/#\1/" /rootfs/boot/config.txt
		echo "gpu_mem=${gpu_mem}" >> /rootfs/boot/config.txt
	fi
fi

# enable hardware watchdog and set up systemd to use it
if [ "${watchdog_enable}" = "1" ]; then
	sed -i "s/^#\(dtparam=watchdog=on\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^dtparam=watchdog=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
		sed -i "s/^\(dtparam=watchdog=.*\)/#\1/" /rootfs/boot/config.txt
		echo "dtparam=watchdog=on" >> /rootfs/boot/config.txt
	fi
	if [ "${init_system}" = "systemd" ]; then
		sed -i 's/^.*RuntimeWatchdogSec=.*$/RuntimeWatchdogSec=14s/' /rootfs/etc/systemd/system.conf
	else
		sed -i "s/^\(#\)*\(max-load-1\t\t= \)\S\+/\224/" /rootfs/etc/watchdog.conf || fail
		sed -i "s/^\(#\)*\(watchdog-device\t\)\(= \)\S\+/\2\t\3\/dev\/watchdog/" /rootfs/etc/watchdog.conf || fail
		if [ "$(grep -c "^\(#\)*watchdog-timeout" /etc/watchdog.conf)" -eq 1 ]; then
			sed -i "s/^\(#\)*\(watchdog-timeout\t= \)\S\+/\214/" /rootfs/etc/watchdog.conf || fail
		else
			echo -e "watchdog-timeout\t= 14" >> /rootfs/etc/watchdog.conf || fail
		fi
	fi
fi

# set wlan country code
if [ -n "${wlan_country}" ]; then
	if [ -r /rootfs/etc/wpa_supplicant/wpa_supplicant.conf ]; then
		inputfile_sanitize /rootfs/etc/wpa_supplicant/wpa_supplicant.conf
		if ! grep -q "country=" /rootfs/etc/wpa_supplicant/wpa_supplicant.conf; then
			echo "country=${wlan_country}" >> /rootfs/etc/wpa_supplicant/wpa_supplicant.conf
		fi
	else
		mkdir -p /rootfs/etc/wpa_supplicant/
		echo "country=${wlan_country}" >> /rootfs/etc/wpa_supplicant/wpa_supplicant.conf
		chmod 600 /rootfs/etc/wpa_supplicant/wpa_supplicant.conf
	fi
fi

# disable wlan country warning
if [ -e "/rootfs/etc/wifi-country.sh" ]; then
	sed -i "1 iexit 0" /rootfs/etc/wifi-country.sh
fi

# set hdmi options
if [ "${hdmi_type}" = "tv" ] || [ "${hdmi_type}" = "monitor" ]; then
	config_set "/rootfs/boot/config.txt" "hdmi_ignore_edid" "0xa5000080"
	config_set "/rootfs/boot/config.txt" "hdmi_drive" "2"
	if [ "${hdmi_type}" = "tv" ]; then
		config_set "/rootfs/boot/config.txt" "hdmi_group" "1"
		if [ "${hdmi_tv_res}" = "720p" ]; then
			#hdmi_mode=4 720p@60Hz
			config_set "/rootfs/boot/config.txt" "hdmi_mode" "4"
		elif [ "${hdmi_tv_res}" = "1080i" ]; then
			#hdmi_mode=5 1080i@60Hz
			config_set "/rootfs/boot/config.txt" "hdmi_mode" "5"
		else
			#hdmi_mode=16 1080p@60Hz
			config_set "/rootfs/boot/config.txt" "hdmi_mode" "16"
		fi
	elif [ "${hdmi_type}" = "monitor" ]; then
		config_set "/rootfs/boot/config.txt" "hdmi_group" "2"
		if [ "${hdmi_monitor_res}" = "640x480" ]; then
			#hdmi_mode=4 640x480@60Hz
			config_set "/rootfs/boot/config.txt" "hdmi_mode" "4"
		elif [ "${hdmi_monitor_res}" = "800x600" ]; then
			#hdmi_mode=9 800x600@60Hz
			config_set "/rootfs/boot/config.txt" "hdmi_mode" "9"
		elif [ "${hdmi_monitor_res}" = "1280x1024" ]; then
			#hdmi_mode=35 1280x1024@60Hz
			config_set "/rootfs/boot/config.txt" "hdmi_mode" "35"
		else
			#hdmi_mode=16 1024x768@60Hz
			config_set "/rootfs/boot/config.txt" "hdmi_mode" "16"
		fi
	fi
fi
if [ "${hdmi_disable_overscan}" = "1" ]; then
	config_set "/rootfs/boot/config.txt" "disable_overscan" "1"
fi

# enable rtc if specified in the configuration file
if [ -n "${rtc}" ]; then
	dtoverlay_enable "/rootfs/boot/config.txt" "i2c-rtc,${rtc}"
	module_enable "rtc-${rtc}" "rtc"
fi

# enable custom dtoverlays
if [ -n "${dt_overlays}" ]; then
	echo "Enabling additional device tree overlays:"
	convert_listvariable dt_overlays
	for dtoverlay in ${dt_overlays}; do
		echo "  ${dtoverlay}"
		dtoverlay_enable "/rootfs/boot/config.txt" "${dtoverlay}"
	done
	echo "OK"
fi

# disable splash if specified in the configuration file
if [ "${disable_splash}" = "1" ]; then
	config_set "/rootfs/boot/config.txt" "disable_splash" "1"
fi

if [ "${sound_enable}" = "1" ] && [ "${sound_usb_enable}" = "1" ] && [ "${sound_usb_first}" = "1" ]; then
	{
		echo "pcm.!default {"
		echo " type hw card 1"
		echo "}"
		echo "ctl.!default {"
		echo " type hw card 1"
		echo "}"
	} > /etc/asound.conf
fi

# set mmc1 (USB) as default trigger for activity led
if [ "${usbroot}" = "1" ]; then
	dtoverlay_enable "/rootfs/boot/config.txt" "act_led_trigger" "mmc1"
fi

# iterate through all the file lists and call the install_files method for them
old_dir=$(pwd)
cd /rootfs/boot/raspberrypi-ua-netinst/config/files/ || fail
for listfile in ./*.list
do
	if [ -e "${listfile}" ]; then
		install_files "${listfile}"
	fi
done
cd "${old_dir}" || fail

# run post install script if exists
if [ -e "/rootfs/boot/raspberrypi-ua-netinst/config/post-install.txt" ]; then
	echo "================================================="
	echo "=== Start executing post-install.txt. ==="
	inputfile_sanitize /rootfs/boot/raspberrypi-ua-netinst/config/post-install.txt
	source /rootfs/boot/raspberrypi-ua-netinst/config/post-install.txt
	echo "=== Finished executing post-install.txt. ==="
	echo "================================================="
fi

# this must be done as the last step, after all package installation and post-install scripts,
# since it will break DNS resolution on the target system until it is rebooted
if [ "${use_systemd_services}" != "0" ]; then
	# ensure that /etc/resolv.conf will be provided by systemd and use systemd's stub resolver
	rm -f /rootfs/etc/resolv.conf
	ln -s /run/systemd/resolve/stub-resolv.conf /rootfs/etc/resolv.conf
fi

# save current time
if echo "${cdebootstrap_cmdline} ${packages_postinstall}" | grep -q "fake-hwclock"; then
	echo -n "Saving current time for fake-hwclock... "
	sync # synchronize before saving time to make it "more accurate"
	date +"%Y-%m-%d %H:%M:%S" > /rootfs/etc/fake-hwclock.data
	echo "OK"
elif [ -n "${rtc}" ]; then
	echo -n "Saving current time to RTC... "
	/opt/busybox/bin/hwclock --systohc --utc || fail
	echo "OK"
fi

ENDTIME=$(date +%s)
DURATION=$((ENDTIME - REAL_STARTTIME))
echo
echo -n "Installation finished at $(date --date="@${ENDTIME}" --utc)"
echo " and took $((DURATION/60)) min $((DURATION%60)) sec (${DURATION} seconds)"
echo
killall -q nc
echo "Printing console to telnet output stopped."

# copy logfile to standard log directory
if [ "${cleanup_logfiles}" = "1" ]; then
	rm -f /rootfs/boot/raspberrypi-ua-netinst/error-*.log
else
	sleep 1
	# root, user and wifi passwords are deleted from logfile before it is written to the filesystem
	sed "/rootpw/d;/userpw/d;/wlan_psk/d" "${logfile}" > /rootfs/var/log/raspberrypi-ua-netinst.log
	chmod 0640 /rootfs/var/log/raspberrypi-ua-netinst.log
fi

# remove clear text wifi password from installer config
if [ -n "${wlan_psk}" ]; then
	sed -i "s/wlan_psk=.*/wlan_psk_encrypted=${wlan_psk_encrypted}/" "/rootfs/boot/raspberrypi-ua-netinst/config/installer-config.txt"
fi

# Cleanup installer files
rm -f "/rootfs${installer_retriesfile}"
if [ -e "${installer_swapfile}" ]; then
	swapoff "${installer_swapfile}"
	rm -f "${installer_swapfile}"
fi
if [ "${cleanup}" = "1" ]; then
	echo -n "Removing installer files... "
	rm -rf /rootfs/boot/raspberrypi-ua-netinst/
	echo "OK"
fi

if [ "${final_action}" != "console" ]; then
	if [ "${ip_addr}" = "dhcp" ]; then
		echo -n "Releasing IP... "
		killall -q udhcpc
		echo "OK"
	fi

	echo -n "Unmounting filesystems... "
	for sysfolder in /sys /proc /dev/pts /dev; do
		umount "/rootfs${sysfolder}"
	done
	sync
	umount /rootfs/boot
	umount /rootfs
	echo "OK"
fi

case ${final_action} in
	poweroff)
		echo -n "Finished! Powering off in 5 seconds... "
		;;
	halt)
		echo -n "Finished! Halting in 5 seconds... "
		;;
	console)
		echo -n "Finished!"
		;;
	*)
		echo -n "Finished! Rebooting to installed system in 5 seconds... "
		final_action=reboot
esac

if [ "${final_action}" != "console" ]; then
	for i in $(seq 5 -1 1); do
		sleep 1
		echo -n "${i}.. "
	done
	echo "0"
	${final_action}
fi
