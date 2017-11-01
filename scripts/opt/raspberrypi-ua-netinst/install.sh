#!/bin/bash

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
	installer_retries=
	installer_fail_blocking=
	cmdline_custom=

	# config variables
	preset=
	packages=
	firmware_packages=
	mirror=
	mirror_cache=
	release=
	hostname=
	boot_volume_label=
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
	final_action=
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

	# set config defaults
	variable_set "preset" "server"
	variable_set "mirror" "http://mirrordirector.raspbian.org/raspbian/"
	variable_set "release" "stretch"
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
	variable_set "ip_netmask" "0.0.0.0"
	variable_set "ip_broadcast" "0.0.0.0"
	variable_set "ip_gateway" "0.0.0.0"
	variable_set "ip_ipv6" "1"
	variable_set "hdmi_tv_res" "1080p"
	variable_set "hdmi_monitor_res" "1024x768"
	variable_set "hdmi_disable_overscan" "0"
	variable_set "hdmi_system_only" "0"
	variable_set "usbroot" "0"
	variable_set "usbboot" "0"
	variable_set "cmdline" "dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 elevator=deadline fsck.repair=yes"
	variable_set "rootfstype" "f2fs"
	variable_set "final_action" "reboot"
	variable_set "hwrng_support" "1"
	variable_set "watchdog_enable" "0"
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
}

led_sos() {
	local led0=/sys/class/leds/led0 # Power LED
	local led1=/sys/class/leds/led1 # Activity LED
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

	if [ -e /sys/class/leds/led0 ]; then (echo none > /sys/class/leds/led0/trigger || true) &> /dev/null; else led0=; fi
	if [ -e /sys/class/leds/led1 ]; then (echo none > /sys/class/leds/led1/trigger || true) &> /dev/null; else led1=; fi
	for i in $(seq 1 3); do
		if [ -n "$led0" ]; then (echo ${led_on} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "$led1" ]; then (echo ${led_on} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.225s;
		if [ -n "$led0" ]; then (echo ${led_off} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "$led1" ]; then (echo ${led_off} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.15s;
	done
	sleep 0.075s;
	for i in $(seq 1 3); do
		if [ -n "$led0" ]; then (echo ${led_on} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "$led1" ]; then (echo ${led_on} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.6s;
		if [ -n "$led0" ]; then (echo ${led_off} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "$led1" ]; then (echo ${led_off} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.15s;
	done
	sleep 0.075s;
	for i in $(seq 1 3); do
		if [ -n "$led0" ]; then (echo ${led_on} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "$led1" ]; then (echo ${led_on} > "${led1}"/brightness || true) &> /dev/null; fi
		sleep 0.225s;
		if [ -n "$led0" ]; then (echo ${led_off} > "${led0}"/brightness || true) &> /dev/null; fi
		if [ -n "$led1" ]; then (echo ${led_off} > "${led1}"/brightness || true) &> /dev/null; fi
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
	cp "${logfile}" "/boot/raspberrypi-ua-netinst/error-$(date +%Y%m%dT%H%M%S).log"
	sync

	if [ -e "/boot/raspberrypi-ua-netinst/config/installer-retries.txt" ]; then
		inputfile_sanitize /boot/raspberrypi-ua-netinst/config/installer-retries.txt
		# shellcheck disable=SC1091
		source /boot/raspberrypi-ua-netinst/config/installer-retries.txt
	fi
	variable_set "installer_retries" "3"
	installer_retries=$((installer_retries-1))
	if [ "${installer_retries}" -ge "0" ]; then
		echo "installer_retries=${installer_retries}" > /boot/raspberrypi-ua-netinst/config/installer-retries.txt
		sync
	fi
	if [ "${installer_retries}" -le "0" ] || [ "${installer_fail_blocking}" = "1" ]; then
		if [ "${installer_retries}" -le "0" ]; then
			echo "  The maximum number of retries is reached!"
			echo "  Check the logfiles for errors. Then delete or edit \"installer-retries.txt\" in installer config folder to (re)set the counter."
		fi
		echo "  The system is stopped to prevent an infinite loop."
		while true; do
			led_sos
		done
	else
		echo "  ${installer_retries} retries left."
	fi

	# if we mounted /boot in the fail command, unmount it.
	if [ "${fail_boot_mounted}" = true ]; then
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
	inputfile_sanitize "/bootfs/raspberrypi-ua-netinst/config/files/${file_to_read}"
	grep -v "^[[:space:]]*#\|^[[:space:]]*$" "/bootfs/raspberrypi-ua-netinst/config/files/${file_to_read}" | while read -r line; do
		owner=$(echo "${line}" | awk '{ print $1 }')
		perms=$(echo "${line}" | awk '{ print $2 }')
		file=$(echo "${line}" | awk '{ print $3 }')
		echo "  ${file}"
		if [ ! -d "/bootfs/raspberrypi-ua-netinst/config/files/root${file}" ]; then
			mkdir -p "/rootfs$(dirname "${file}")"
			cp "/bootfs/raspberrypi-ua-netinst/config/files/root${file}" "/rootfs${file}"
		else
			mkdir -p "/rootfs/${file}"
		fi
		chmod "${perms}" "/rootfs${file}"
		chroot /rootfs chown "${owner}" "${file}"
	done
	echo
}

output_filter() {
	local filterstring
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

	while IFS= read -r line ; do
		if [[ "$line" =~ ${filterstring} ]] ; then
			:
		else
			echo "  $line"
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

#######################
###    INSTALLER    ###
#######################

# clear variables
variables_reset

# preset installer variables
logfile=/tmp/raspberrypi-ua-netinst.log
rootdev=/dev/mmcblk0
wlan_configfile=/bootfs/raspberrypi-ua-netinst/config/wpa_supplicant.conf
final_action=reboot

mkdir -p /proc
mkdir -p /sys
mkdir -p /boot
mkdir -p /usr/bin
mkdir -p /usr/sbin
mkdir -p /var/run
mkdir -p /etc/raspberrypi-ua-netinst
mkdir -p /rootfs/boot
mkdir -p /bootfs
mkdir -p /tmp/
mkdir -p /opt/busybox/bin/

/bin/busybox --install /opt/busybox/bin/
ln -s /opt/busybox/bin/sh /bin/sh

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/busybox/bin
# put PATH in /etc/profile so it's also available when we get a busybox shell
echo "export PATH=${PATH}" > /etc/profile

mount -t proc proc /proc
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
		# shellcheck disable=SC1091
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

echo -n "Starting HWRNG... "
if /usr/sbin/rngd -r /dev/hwrng; then
	echo "OK"
else
	echo "FAILED! (continuing to use the software RNG)"
fi

echo -n "Mounting boot partition... "
mount "${bootpartition}" /boot || fail
echo "OK"

# copy boot data to safety
echo -n "Copying boot files... "
cp -r /boot/* /bootfs/ || fail
echo "OK"

# Read installer-config.txt
if [ -e "/bootfs/raspberrypi-ua-netinst/config/installer-config.txt" ]; then
	echo "Executing installer-config.txt..."
	inputfile_sanitize /bootfs/raspberrypi-ua-netinst/config/installer-config.txt
	# shellcheck disable=SC1091
	source /bootfs/raspberrypi-ua-netinst/config/installer-config.txt
	echo "OK"
fi

# Setting default variables
variables_set_defaults

preinstall_reboot=0
echo
echo "Checking if config.txt needs to be modified before starting installation..."
# Reinstallation
if [ -e "/boot/raspberrypi-ua-netinst/reinstall/kernel.img" ] && [ -e "/boot/raspberrypi-ua-netinst/reinstall/kernel7.img" ] ; then
	echo -n "  Reinstallation requested! Restoring files... "
	mv /boot/raspberrypi-ua-netinst/reinstall/kernel.img /boot/kernel.img
	mv /boot/raspberrypi-ua-netinst/reinstall/kernel7.img /boot/kernel7.img
	echo "OK"
	preinstall_reboot=1
fi
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
		echo -e "\ndtoverlay=i2c-rtc,${rtc}" >> /boot/config.txt
		preinstall_reboot=1
	fi
	echo "OK"
fi
# MSD boot
if [ "${usbboot}" = "1" ] ; then
	echo -n "  Checking USB boot flag... "
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
umount /boot || fail
echo "OK"

if [ -e "${wlan_configfile}" ]; then
	inputfile_sanitize "${wlan_configfile}"
fi

echo
echo "Network configuration:"
echo "  ifname = ${ifname}"
echo "  ip_addr = ${ip_addr}"

if [ "${ip_addr}" != "dhcp" ]; then
	echo "  ip_netmask = ${ip_netmask}"
	echo "  ip_broadcast = ${ip_broadcast}"
	echo "  ip_gateway = ${ip_gateway}"
	echo "  ip_nameservers = ${ip_nameservers}"
fi

if echo "${ifname}" | grep -q "wlan"; then
	if [ ! -e "${wlan_configfile}" ]; then
		wlan_configfile=/tmp/wpa_supplicant.conf
		echo "  wlan_ssid = ${wlan_ssid}"
		echo "  wlan_psk = ${wlan_psk}"
		{
			echo "network={"
			echo "    scan_ssid=1"
			echo "    ssid=\"${wlan_ssid}\""
			echo "    psk=\"${wlan_psk}\""
			echo "}"
		} > ${wlan_configfile}
	fi
	if [ -n "${wlan_country}" ] && ! grep -q "country=" ${wlan_configfile}; then
		echo "country=${wlan_country}" >> ${wlan_configfile}
	fi
fi

echo "  online_config = ${online_config}"
echo

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

echo -n "Waiting for ${ifname}... "
for i in $(seq 1 15); do
	if ifconfig "${ifname}" &>/dev/null; then
		break
	fi
	if [ "${i}" -eq 10 ]; then
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
		echo -n "Starting wpa_supplicant... "
		if [ -e "${wlan_configfile}" ]; then
			if wpa_supplicant -B -Dnl80211 -c"${wlan_configfile}" -i"${ifname}"; then
				echo "OK"
			else
				echo "nl80211 driver didn't work. Trying generic driver (wext)..."
				wpa_supplicant -B -Dwext -c"${wlan_configfile}" -i"${ifname}" || fail
				echo "OK"
			fi
		fi
	fi
fi

if [ "${ip_addr}" = "dhcp" ]; then
	echo -n "Configuring ${ifname} with DHCP... "

	if udhcpc -i "${ifname}" &>/dev/null; then
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

# This will record the time to get to this point
PRE_NETWORK_DURATION=$(date +%s)

date_set=false
if [ "${date_set}" = "false" ]; then
	# set time with ntpdate
	echo -n "Set time using ntpdate... "
	if ntpdate-debian -b &>/dev/null; then
		echo "OK"
		date_set=true
	fi

	if [ "${date_set}" = "false" ]; then
		echo "Failed to set time via ntpdate. Switched to rdate."
		# failed to set time with ntpdate, fall back to rdate
		# time server addresses taken from http://tf.nist.gov/tf-cgi/servers.cgi
		timeservers="${timeserver}"
		timeservers="${timeservers} time.nist.gov nist1.symmetricom.com"
		timeservers="${timeservers} nist-time-server.eoni.com utcnist.colorado.edu"
		timeservers="${timeservers} nist1-pa.ustiming.org nist.expertsmi.com"
		timeservers="${timeservers} nist1-macon.macon.ga.us wolfnisttime.com"
		timeservers="${timeservers} nist.time.nosc.us nist.netservicesgroup.com"
		timeservers="${timeservers} nisttime.carsoncity.k12.mi.us nist1-lnk.binary.net"
		timeservers="${timeservers} ntp-nist.ldsbc.edu utcnist2.colorado.edu"
		timeservers="${timeservers} nist1-ny2.ustiming.org wwv.nist.gov"
		echo -n "Set time using timeserver "
		for ts in ${timeservers}; do
			echo -n "'${ts}'... "
			if rdate "${ts}" &>/dev/null; then
				echo "OK"
				date_set=true
				break
			fi
		done
	fi

	if [ "${date_set}" = "false" ]; then
		echo "Failed to set time via rdate. Switched to HTTP."
		# Try to set time via http to work behind proxies.
		# Timeserver has to return the time in the format: YYYY-MM-DD HH:MM:SS.
		timeservers_http="${timeserver_http}"
		timeservers_http="${timeservers_http} http://chronic.herokuapp.com/utc/now?format=%25F+%25T"
		timeservers_http="${timeservers_http} http://www.timeapi.org/utc/now?format=%25F+%25T"
		echo -n "Set time using HTTP timeserver "
		for ts_http in ${timeservers_http}; do
			echo -n "'${ts_http}'... "
			http_time="$(wget -q -O - "${ts_http}")"
			if date -u -s "${http_time}" &>/dev/null; then
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
	wget -q -O /opt/raspberrypi-ua-netinst/installer-config_online.txt "${online_config}" &>/dev/null || fail
	echo "OK"

	echo -n "Executing online-config.txt... "
	inputfile_sanitize /opt/raspberrypi-ua-netinst/installer-config_online.txt
	# shellcheck disable=SC1091
	source /opt/raspberrypi-ua-netinst/installer-config_online.txt
	variables_set_defaults
	echo "OK"
fi

# prepare rootfs mount options
case "${rootfstype}" in
	"btrfs")
		kernel_module=true
		rootfs_mkfs_options=${rootfs_mkfs_options:-'-f'}
		rootfs_install_mount_options=${rootfs_install_mount_options:-'noatime'}
		rootfs_mount_options=${rootfs_mount_options:-'noatime'}
	;;
	"ext4")
		kernel_module=true
		rootfs_mkfs_options=${rootfs_mkfs_options:-''}
		rootfs_install_mount_options=${rootfs_install_mount_options:-'noatime,data=writeback,nobarrier,noinit_itable'}
		rootfs_mount_options=${rootfs_mount_options:-'errors=remount-ro,noatime'}
	;;
	"f2fs")
		kernel_module=true
		rootfs_mkfs_options=${rootfs_mkfs_options:-''}
		rootfs_install_mount_options=${rootfs_install_mount_options:-'noatime'}
		rootfs_mount_options=${rootfs_mount_options:-'noatime'}
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
release_fallback=stretch
release_base="${release}"
release_raspbian="${release}"
if ! wget --spider "${mirror_base}/${release}/" &> /dev/null; then
	release_base="${release_fallback}"
fi
if ! wget --spider "${mirror}/dists/${release}/" &> /dev/null; then
	release_raspbian="${release_fallback}"
fi

# configure different kinds of presets
if [ -z "${cdebootstrap_cmdline}" ]; then
	# from small to large: base, minimal, server
	# not very logical that minimal > base, but that's how it was historically defined

	init_system=""
	if [ "${release}" = "wheezy" ]; then
		init_system="sysvinit"
	else
		init_system="systemd"
	fi

	# always add packages if requested or needed
	if [ "${firmware_packages}" = "1" ]; then
		custom_packages_postinstall="${custom_packages_postinstall},firmware-atheros,firmware-brcm80211,firmware-libertas,firmware-ralink,firmware-realtek"
	fi
	if [ -n "${locales}" ] || [ -n "${system_default_locale}" ]; then
		custom_packages="${custom_packages},locales"
	fi
	if [ -n "${keyboard_layout}" ] && [ "${keyboard_layout}" != "us" ]; then
		custom_packages="${custom_packages},console-setup"
	fi
	if [ "${watchdog_enable}" = "1" ] && [ "${init_system}" = "sysvinit" ]; then
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
	base_packages="cpufrequtils,kmod,raspbian-archive-keyring"
	base_packages="${custom_packages},${base_packages}"
	base_packages_postinstall=raspberrypi-bootloader
	if [ "${release}" != "wheezy" ]; then
		base_packages_postinstall="${base_packages_postinstall},raspberrypi-kernel"
	fi
	base_packages_postinstall="${custom_packages_postinstall},${base_packages_postinstall}"
	if [ "${init_system}" = "systemd" ]; then
		base_packages="${base_packages},libpam-systemd"
	fi
	if [ "${hwrng_support}" = "1" ]; then
		base_packages="${base_packages},rng-tools"
	fi
	if [ "$(find /bootfs/raspberrypi-ua-netinst/config/apt/ -maxdepth 1 -type f -name "*.list" 2>/dev/null | wc -l)" != 0 ]; then
		base_packages="${base_packages},apt-transport-https"
	fi
	
	# minimal
	minimal_packages="ifupdown,net-tools,openssh-server,dosfstools"
	if [ "${init_system}" != "systemd" ]; then
		minimal_packages="${minimal_packages},ntp"
	fi
	if [ -z "${rtc}" ]; then
		minimal_packages="${minimal_packages},fake-hwclock"
	fi
	if [ "${release}" != "wheezy" ]; then
		minimal_packages_postinstall="${minimal_packages_postinstall},raspberrypi-sys-mods"
	fi
	minimal_packages_postinstall="${base_packages_postinstall},${minimal_packages_postinstall}"
	if echo "${ifname}" | grep -q "wlan"; then
		minimal_packages_postinstall="${minimal_packages_postinstall},firmware-brcm80211"
	fi

	# server
	server_packages="vim-tiny,iputils-ping,wget,ca-certificates,rsyslog,cron,dialog,locales,tzdata,less,man-db,logrotate,bash-completion,console-setup,apt-utils"
	server_packages_postinstall="libraspberrypi-bin,raspi-copies-and-fills"
	server_packages_postinstall="${minimal_packages_postinstall},${server_packages_postinstall}"
	if [ "${init_system}" = "systemd" ]; then
		server_packages="${server_packages},systemd-sysv"
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

	dhcp_client_package="isc-dhcp-client"
	# add IPv4 DHCP client if needed
	if [ "${ip_addr}" = "dhcp" ]; then
		cdebootstrap_cmdline="${cdebootstrap_cmdline},${dhcp_client_package}"
	fi

	# add user defined syspackages
	if [ -n "${syspackages}" ]; then
		cdebootstrap_cmdline="${cdebootstrap_cmdline},${syspackages}"
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
echo "  packages_postinstall = ${packages_postinstall}"
echo "  boot_volume_label = ${boot_volume_label}"
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

if [ -n "${rtc}" ] ; then
	echo -n "Checking hardware clock access... "
	/opt/busybox/bin/hwclock --show &>/dev/null || fail
	echo "OK"
	echo
fi

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
	dd if=/dev/zero of="${bootdev}" bs=512 count=1 &>/dev/null
	fdisk "${bootdev}" &>/dev/null < "${FDISK_SCHEME_SD_ONLY}"
	echo "OK"
else
	echo -n "Applying new partition table for ${bootdev}... "
	dd if=/dev/zero of="${bootdev}" bs=512 count=1 &>/dev/null
	fdisk "${bootdev}" &>/dev/null < "${FDISK_SCHEME_SD_BOOT}"
	echo "OK"

	echo -n "Applying new partition table for ${rootdev}... "
	dd if=/dev/zero of="${rootdev}" bs=512 count=1 &>/dev/null
	fdisk "${rootdev}" &>/dev/null < "${FDISK_SCHEME_USB_ROOT}"
	echo "OK"
fi

# refresh the /dev device nodes
mdev -s

echo -n "Initializing /boot as vfat... "
if [ -z "${boot_volume_label}" ]; then
	mkfs.vfat "${bootpartition}" &>/dev/null || fail
else
	mkfs.vfat -n "${boot_volume_label}" "${bootpartition}" &>/dev/null || fail
fi
echo "OK"

echo -n "Copying /boot files in... "
mount "${bootpartition}" /boot || fail
cp -r /bootfs/* /boot || fail
sync
umount /boot || fail
echo "OK"

if [ "${kernel_module}" = true ]; then
  if [ "${rootfstype}" != "ext4" ]; then
	echo -n "Loading ${rootfstype} module... "
	modprobe "${rootfstype}" &> /dev/null || fail
	echo "OK"
  fi
fi

echo -n "Initializing / as ${rootfstype}... "
eval mkfs."${rootfstype}" "${rootfs_mkfs_options}" "${rootpartition}" &> /dev/null || fail
echo "OK"

echo -n "Mounting new filesystems... "
mount "${rootpartition}" /rootfs -o "${rootfs_install_mount_options}" || fail
mkdir /rootfs/boot || fail
mount "${bootpartition}" /rootfs/boot || fail
echo "OK"

if [ "${kernel_module}" = true ]; then
  if [ "${rootfstype}" != "ext4" ]; then
	mkdir -p /rootfs/etc/initramfs-tools
	echo "${rootfstype}" >> /rootfs/etc/initramfs-tools/modules
  fi
fi

echo
echo "Starting install process..."
for i in $(seq 1 3); do
	if [ -n "${mirror_cache}" ]; then
		export http_proxy="http://${mirror_cache}/"
	fi
	eval cdebootstrap-static --arch=armhf "${cdebootstrap_cmdline}" "${release_raspbian}" /rootfs "${mirror}" --keyring=/usr/share/keyrings/raspbian-archive-keyring.gpg 2>&1 | output_filter
	cdebootstrap_exitcode="${PIPESTATUS[0]}"
	if [ "${cdebootstrap_exitcode}" -eq 0 ]; then
		unset http_proxy
		break
	else
		unset http_proxy
		if [ "${i}" -eq 3 ]; then
			echo
			echo "  ERROR: ${cdebootstrap_exitcode}"
			fail
		else
			echo "  ERROR: ${cdebootstrap_exitcode}, trying again ($((i+1))/3)..."
		fi
	fi
done

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
		if [ -f "/bootfs/raspberrypi-ua-netinst/config/files/${root_ssh_pubkey}" ]; then
			echo -n " from file '${root_ssh_pubkey}'... "
			cp "/bootfs/raspberrypi-ua-netinst/config/files/${root_ssh_pubkey}" /rootfs/root/.ssh/authorized_keys || fail
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
# openssh-server in jessie and higher doesn't allow root to login with a password
if [ "${root_ssh_pwlogin}" = "1" ]; then
	if [ "${release_raspbian}" != "wheezy" ]; then
		if [ -f /rootfs/etc/ssh/sshd_config ]; then
			echo -n "  Allowing root to login with password... "
			sed -i '/PermitRootLogin/s/.*/PermitRootLogin yes/' /rootfs/etc/ssh/sshd_config || fail
			echo "OK"
		fi
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
			if [ -f "/bootfs/raspberrypi-ua-netinst/config/files/${user_ssh_pubkey}" ]; then
				echo -n " from file '${user_ssh_pubkey}'... "
				cp "/bootfs/raspberrypi-ua-netinst/config/files/${user_ssh_pubkey}" "/rootfs/home/${username}/.ssh/authorized_keys" || fail
				echo "OK"
			else
				echo -n "... "
				echo "${user_ssh_pubkey}" > "/rootfs/home/${username}/.ssh/authorized_keys"
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
			echo "OK"
		fi
	fi
fi

# default mounts
echo -n "  Configuring /etc/fstab... "
touch /rootfs/etc/fstab || fail
{
	echo "${bootpartition} /boot vfat defaults 0 2"
	if [ "${rootfstype}" = "f2fs" ]; then
		echo "${rootpartition} / ${rootfstype} ${rootfs_mount_options} 0 0"
	elif [ "${rootfstype}" = "btrfs" ]; then
		echo "${rootpartition} / ${rootfstype} ${rootfs_mount_options} 0 0"
	else
		echo "${rootpartition} / ${rootfstype} ${rootfs_mount_options} 0 1"
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

# networking
if echo "${cdebootstrap_cmdline} ${packages_postinstall}" | grep -q "ifupdown"; then
	echo -n "  Configuring network settings... "
	
	if [ "${ip_ipv6}" = "0" ]; then
		mkdir -p /rootfs/etc/sysctl.d
		echo "net.ipv6.conf.all.disable_ipv6 = 1" > /rootfs/etc/sysctl.d/01-disable-ipv6.conf
	fi
	
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
	
	# Customize cmdline.txt
	if [ "${disable_predictable_nin}" = "1" ]; then
		# as described here: https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames
		# adding net.ifnames=0 to /boot/cmdline and disabling the persistent-net-generator.rules
		line_add cmdline_custom "net.ifnames=0"
		ln -s /dev/null /rootfs/etc/udev/rules.d/75-persistent-net-generator.rules
	fi
	
	if [ "${ip_addr}" != "dhcp" ]; then
		cp /etc/resolv.conf /rootfs/etc/ || fail
	fi
	
	echo "OK"
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

# if there is no hw clock on rpi
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

# enable NTP client on systemd releases
if [ "${init_system}" = "systemd" ]; then
	ln -s /usr/lib/systemd/system/systemd-timesyncd.service /rootfs/etc/systemd/system/multi-user.target.wants/systemd-timesyncd.service
fi

# copy apt's sources.list to the target system
echo "Configuring apt:"
echo -n "  Configuring Raspbian repository... "
if [ -e "/bootfs/raspberrypi-ua-netinst/config/apt/sources.list" ]; then
	sed "s/__RELEASE__/${release_raspbian}/g" "/bootfs/raspberrypi-ua-netinst/config/apt/sources.list" > "/rootfs/etc/apt/sources.list" || fail
	cp /bootfs/raspberrypi-ua-netinst/config/apt/sources.list /rootfs/etc/apt/sources.list || fail
else
	sed "s/__RELEASE__/${release_raspbian}/g" "/opt/raspberrypi-ua-netinst/res/etc/apt/sources.list" > "/rootfs/etc/apt/sources.list" || fail
fi
echo "OK"
# if __RELEASE__ is still present, something went wrong
echo -n "  Checking Raspbian repository entry... "
if grep -l '__RELEASE__' /rootfs/etc/apt/sources.list >/dev/null; then
	fail
else
	echo "OK"
fi
echo -n "  Adding raspberrypi.org GPG key to apt-key... "
(chroot /rootfs /usr/bin/apt-key add - &>/dev/null) < /usr/share/keyrings/raspberrypi.gpg.key || fail
echo "OK"

echo -n "  Configuring RaspberryPi repository... "
if [ -e "/bootfs/raspberrypi-ua-netinst/config/apt/raspberrypi.org.list" ]; then
	sed "s/__RELEASE__/${release_base}/g" "/bootfs/raspberrypi-ua-netinst/config/apt/raspberrypi.org.list" > "/rootfs/etc/apt/sources.list.d/raspberrypi.org.list" || fail
else
	sed "s/__RELEASE__/${release_base}/g" "/opt/raspberrypi-ua-netinst/res/etc/apt/raspberrypi.org.list" > "/rootfs/etc/apt/sources.list.d/raspberrypi.org.list" || fail
fi
echo "OK"
echo -n "  Configuring RaspberryPi preference... "
if [ -e "/bootfs/raspberrypi-ua-netinst/config/apt/archive_raspberrypi_org.pref" ]; then
	sed "s/__RELEASE__/${release_base}/g" "/bootfs/raspberrypi-ua-netinst/config/apt/archive_raspberrypi_org.pref" > "/rootfs/etc/apt/preferences.d/archive_raspberrypi_org.pref" || fail
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
for i in $(seq 1 3); do
	if chroot /rootfs /usr/bin/apt-get -o Acquire::http::Proxy=http://"${mirror_cache}" update &>/dev/null; then
		echo "OK"
		break
	else
		update_exitcode="${?}"
		if [ "${i}" -eq 3 ]; then
			echo "ERROR: ${update_exitcode}, FAILED !"
			fail
		else
			echo -n "ERROR: ${update_exitcode}, trying again ($((i+1))/3)... "
		fi
	fi
done

# kernel and firmware package can't be installed during cdebootstrap phase, so do so now
if [ "${kernel_module}" = true ]; then
	if [ -n "${packages_postinstall}" ]; then
		convert_listvariable packages_postinstall
	fi

	DEBIAN_FRONTEND=noninteractive
	export DEBIAN_FRONTEND

	echo
	echo "Downloading packages..."
	for i in $(seq 1 5); do
		eval chroot /rootfs /usr/bin/apt-get -o Acquire::http::Proxy=http://"${mirror_cache}" -y -d install "${packages_postinstall}" 2>&1 | output_filter
		download_exitcode="${PIPESTATUS[0]}"
		if [ "${download_exitcode}" -eq 0 ]; then
			echo "OK"
			break
		else
			if [ "${i}" -eq 3 ]; then
				echo "ERROR: ${download_exitcode}, FAILED !"
				fail
			else
				echo -n "ERROR: ${download_exitcode}, trying again ($((i+1))/5)... "
			fi
		fi
	done

	echo
	echo "Installing kernel, bootloader (=firmware) and user packages..."
	eval chroot /rootfs /usr/bin/apt-get -o Acquire::http::Proxy=http://"${mirror_cache}" -y install "${packages_postinstall}" 2>&1 | output_filter
	if [ "${PIPESTATUS[0]}" -eq 0 ]; then
		echo "OK"
	else
		echo "FAILED !"
	fi
	
	unset DEBIAN_FRONTEND
fi

echo "Preserving original config.txt and kernels..."
mkdir -p /rootfs/boot/raspberrypi-ua-netinst/reinstall
cp /bootfs/config.txt /rootfs/boot/raspberrypi-ua-netinst/reinstall/config.txt
cp /bootfs/kernel.img /rootfs/boot/raspberrypi-ua-netinst/reinstall/kernel.img
cp /bootfs/kernel7.img /rootfs/boot/raspberrypi-ua-netinst/reinstall/kernel7.img
echo "Configuring bootloader to start the installed system..."
if [ -e "/bootfs/raspberrypi-ua-netinst/config/boot/config.txt" ]; then
	cp /bootfs/raspberrypi-ua-netinst/config/boot/config.txt /rootfs/boot/config.txt
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

# create cmdline.txt
echo -n "Creating cmdline.txt... "
line_add cmdline "root=${rootpartition} rootfstype=${rootfstype} rootwait"
line_add_if_boolean quiet_boot cmdline_custom "quiet" "loglevel=3"
line_add_if_boolean disable_raspberries cmdline_custom "logo.nologo"
line_add_if_set console_blank cmdline_custom "consoleblank=${console_blank}"
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
	echo "i2c-dev" >> /rootfs/etc/modules
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
	if [ "${init_system}" = "sysvinit" ]; then
		sed -i "s/^\(#\)*\(max-load-1\t\t= \)\S\+/\224/" /rootfs/etc/watchdog.conf || fail
		sed -i "s/^\(#\)*\(watchdog-device\t\)\(= \)\S\+/\2\t\3\/dev\/watchdog/" /rootfs/etc/watchdog.conf || fail
		if [ "$(grep -c "^\(#\)*watchdog-timeout" /etc/watchdog.conf)" -eq 1 ]; then
			sed -i "s/^\(#\)*\(watchdog-timeout\t= \)\S\+/\214/" /rootfs/etc/watchdog.conf || fail
		else
			echo -e "watchdog-timeout\t= 14" >> /rootfs/etc/watchdog.conf || fail
		fi
	elif [ "${init_system}" = "systemd" ]; then
		sed -i 's/^.*RuntimeWatchdogSec=.*$/RuntimeWatchdogSec=14s/' /rootfs/etc/systemd/system.conf
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
	sed -i "s/^#\(dtoverlay=i2c-rtc,${rtc}\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^dtoverlay=i2c-rtc,.*" /rootfs/boot/config.txt)" -ne 1 ]; then
		sed -i "s/^\(dtoverlay=i2c-rtc,\)/#\1/" /rootfs/boot/config.txt
		echo "dtoverlay=i2c-rtc,${rtc}" >> /rootfs/boot/config.txt
	fi
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
if [ -e "/bootfs/raspberrypi-ua-netinst/config/post-install.txt" ]; then
	echo "================================================="
	echo "=== Start executing post-install.txt. ==="
	inputfile_sanitize /bootfs/raspberrypi-ua-netinst/config/post-install.txt
	# shellcheck disable=SC1091
	source /bootfs/raspberrypi-ua-netinst/config/post-install.txt
	echo "=== Finished executing post-install.txt. ==="
	echo "================================================="
fi

# remove cdebootstrap-helper-rc.d which prevents rc.d scripts from running
echo -n "Removing cdebootstrap-helper-rc.d... "
chroot /rootfs /usr/bin/dpkg -r cdebootstrap-helper-rc.d &>/dev/null || fail
echo "OK"

# save current time
if [ -z "${rtc}" ]; then
	echo -n "Saving current time for fake-hwclock... "
	sync # synchronize before saving time to make it "more accurate"
	date +"%Y-%m-%d %H:%M:%S" > /rootfs/etc/fake-hwclock.data
	echo "OK"
else
	echo -n "Saving current time to RTC... "
	/opt/busybox/bin/hwclock --systohc || fail
	echo "OK"
fi

ENDTIME=$(date +%s)
DURATION=$((ENDTIME - REAL_STARTTIME))
echo
echo -n "Installation finished at $(date --date="@${ENDTIME}" --utc)"
echo " and took $((DURATION/60)) min $((DURATION%60)) sec (${DURATION} seconds)"

# copy logfile to standard log directory
if [ "${cleanup_logfiles}" = "1" ]; then
	rm -f /rootfs/boot/raspberrypi-ua-netinst/error-*.log
else
	sleep 1
	cp "${logfile}" /rootfs/var/log/raspberrypi-ua-netinst.log
	chmod 0640 /rootfs/var/log/raspberrypi-ua-netinst.log
fi

# Cleanup installer files
echo "installer_retries=3" > /rootfs/boot/raspberrypi-ua-netinst/config/installer-retries.txt
if [ "${cleanup}" = "1" ]; then
	echo -n "Removing installer files... "
	rm -rf /rootfs/boot/raspberrypi-ua-netinst/
	echo "OK"
fi

if [ "${final_action}" != "console" ]; then
	echo -n "Unmounting filesystems... "
	for sysfolder in /dev/pts /proc /sys; do
		umount "/rootfs${sysfolder}"
	done
	sync
	umount /rootfs/boot
	umount /rootfs
	echo "OK"
fi

case ${final_action} in
	poweroff)
		echo -n "Finished! Powering off in 5 seconds..."
		;;
	halt)
		echo -n "Finished! Halting in 5 seconds..."
		;;
	console)
		echo -n "Finished!"
		;;
	*)
		echo -n "Finished! Rebooting to installed system in 5 seconds..."
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
