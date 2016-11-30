#!/bin/bash
# shellcheck disable=SC1091

LOGFILE=/tmp/raspberrypi-ua-netinst.log

# default options, can be overriden in installer-config.txt
preset=server
packages=
firmware_packages=
mirror=http://mirrordirector.raspbian.org/raspbian/
release=jessie
hostname=pi
boot_volume_label=
domainname=
rootpw=raspbian
user_ssh_pubkey=
root_ssh_pubkey=
root_ssh_pwlogin=1
ssh_pwlogin=
username=
userpw=
usergpio=
usergpu=
usergroups=
usersysgroups=
user_is_admin=
cdebootstrap_cmdline=
bootsize=+128M
bootoffset=8192
rootsize=
timeserver=time.nist.gov
timeserver_http=
timezone=Etc/UTC
keyboard_layout=
locales=
system_default_locale=
disable_predictable_nin=1
ifname=eth0
wlan_country=
wlan_ssid=
wlan_psk=
ip_addr=dhcp
ip_netmask=0.0.0.0
ip_broadcast=0.0.0.0
ip_gateway=0.0.0.0
ip_nameservers=
drivers_to_load=
online_config=
gpu_mem=
hdmi_type=
hdmi_tv_res=1080p
hdmi_monitor_res=1024x768
hdmi_system_only=0
usbroot=
usbboot=
cmdline="dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 elevator=deadline fsck.repair=yes"
rootfstype=f2fs
final_action=reboot
hwrng_support=1
enable_watchdog=0
quiet_boot=0
spi_enable=0
i2c_enable=0
i2c_baudrate=
sound_enable=0
camera_enable=0
camera_disable_led=0

# internal variables
rootdev=/dev/mmcblk0
rootpartition=
wlan_configfile=/bootfs/raspberrypi-ua-netinst/config/wpa_supplicant.conf

fail()
{
	echo
	echo "Oh noes, something went wrong!"
	echo "You have 10 seconds to hit ENTER to get a shell..."

	# copy logfile to /boot/raspberrypi-ua-netinst/ to preserve it.
	# test whether the sd card is still mounted on /boot and if not, mount it.
	if [ ! -f /boot/bootcode.bin ]; then
		mount "${bootpartition}" /boot
		fail_boot_mounted=true
	fi
	cp -- ${LOGFILE} /boot/raspberrypi-ua-netinst/error-"$(date +%Y%m%dT%H%M%S)".log
	sync

	# if we mounted /boot in the fail command, unmount it.
	if [ "${fail_boot_mounted}" = true ]; then
		umount /boot
	fi

	read -rt 10 || reboot && exit
	sh
}

sanitize_inputfile()
{
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

# sanitizes variables that use comma separation
sanitize_variable()
{
	local tmp_variable
	tmp_variable="${!1}"
	tmp_variable="$(echo "${tmp_variable}" | tr ' ' ',')"
	while [ "${tmp_variable:0:1}" == "," ]; do
		tmp_variable="${tmp_variable:1}"
	done
	while [ "${tmp_variable: -1}" == "," ]; do
		tmp_variable="${tmp_variable:0:-1}"
	done
	while echo "${tmp_variable}" | grep -q ",,"; do
		tmp_variable="${tmp_variable//,,/,}"
	done
	eval "${1}"="${tmp_variable}"
}

install_files()
{
	file_to_read="${1}"
	echo "Adding files & folders listed in /boot/raspberrypi-ua-netinst/config/files/${file_to_read}..."
	sanitize_inputfile "/bootfs/raspberrypi-ua-netinst/config/files/${file_to_read}"
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

output_filter()
{
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
	filterstring+="|^E: Can not write log \(Is \/dev\/pts mounted\?\) - posix_openpt \(2: No such file or directory\)$"
	filterstring+="|^update-rc\.d: warning: start and stop actions are no longer supported; falling back to defaults$"
	filterstring+="|^invoke-rc\.d: policy-rc\.d denied execution of start\.$"
	filterstring+="|^Failed to set capabilities on file \`\S.*' \(Invalid argument\)$"
	filterstring+="|^The value of the capability argument is not permitted for a file\. Or the file is not a regular \(non-symlink\) file$"
	filterstring+="|^Failed to read \S.*\. Ignoring: No such file or directory$"
	grep -Ev "${filterstring}"
}

# set screen blank period to an hour
# hopefully the install should be done by then
echo -en '\033[9;60]'

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
mkfifo "${LOGFILE}.pipe"
tee < "${LOGFILE}.pipe" "${LOGFILE}" &
exec &> "${LOGFILE}.pipe"
rm "${LOGFILE}.pipe"

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
	"0012") rpi_hardware_version="A+" ;;
	"0013") rpi_hardware_version="B+" ;;
	"0015") rpi_hardware_version="A+" ;;
	"a01040") rpi_hardware_version="2 Model B" ;;
	"a01041") rpi_hardware_version="2 Model B" ;;
	"a21041") rpi_hardware_version="2 Model B" ;;
	"a22042") rpi_hardware_version="2 Model B+" ;;
	"900092") rpi_hardware_version="Zero" ;;
	"900093") rpi_hardware_version="Zero" ;;
	"a02082") rpi_hardware_version="3 Model B" ;;
	"a22082") rpi_hardware_version="3 Model B" ;;
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

echo -n "Starting HWRNG "
if /usr/sbin/rngd -r /dev/hwrng; then
	echo "succeeded!"
else
	echo "FAILED! (continuing to use the software RNG)"
fi

echo -n "Mounting boot partition... "
mount "${bootpartition}" /boot || fail
echo "OK"

# copy boot data to safety
echo -n "Copying boot files... "
cp -r -- /boot/* /bootfs/ || fail
echo "OK"

# Read installer-config.txt
if [ -e "/bootfs/raspberrypi-ua-netinst/config/installer-config.txt" ]; then
	echo -n "Executing installer-config.txt... "
	sanitize_inputfile /bootfs/raspberrypi-ua-netinst/config/installer-config.txt
	source /bootfs/raspberrypi-ua-netinst/config/installer-config.txt
	echo "OK"
fi

preinstall_reboot=0
echo
echo "Checking if config.txt needs to be modified before starting installation..."
# Reinstallation
if [ -e "/boot/raspberrypi-ua-netinst/reinstall/kernel.img" ] && [ -e "/boot/raspberrypi-ua-netinst/reinstall/kernel7.img" ] ; then
	echo "  =================================================="
	echo "  == Reinstallation requested! Restoring files... =="
	mv /boot/raspberrypi-ua-netinst/reinstall/kernel.img /boot/kernel.img
	mv /boot/raspberrypi-ua-netinst/reinstall/kernel7.img /boot/kernel7.img
	echo "  == Done. ========================================="
	echo "  =================================================="
	preinstall_reboot=1
fi
# HDMI settings
if [ "${hdmi_system_only}" = "0" ]; then
	if [ "${hdmi_type}" = "tv" ] || [ "${hdmi_type}" = "monitor" ]; then
		echo "  =================================================="
		echo "  == Setting HDMI options... ======================="
		if ! grep -q "^hdmi_ignore_edid=0xa5000080\>" /boot/config.txt; then echo -e "\nhdmi_ignore_edid=0xa5000080" >> /boot/config.txt; preinstall_reboot=1; fi
		if ! grep -q "^hdmi_drive=2\>" /boot/config.txt; then echo "hdmi_drive=2" >> /boot/config.txt; preinstall_reboot=1; fi
		if [ "${hdmi_type}" = "tv" ]; then
			if ! grep -q "^hdmi_group=1\>" /boot/config.txt; then echo "hdmi_group=1" >> /boot/config.txt; preinstall_reboot=1; fi
			if [ "${hdmi_tv_res}" = "720p" ]; then
				if ! grep -q "^hdmi_mode=4\>" /boot/config.txt; then echo "hdmi_mode=4" >> /boot/config.txt; preinstall_reboot=1; fi
			elif [ "${hdmi_tv_res}" = "1080i" ]; then
				if ! grep -q "^hdmi_mode=5\>" /boot/config.txt; then echo "hdmi_mode=5" >> /boot/config.txt; preinstall_reboot=1; fi
			else
				if ! grep -q "^hdmi_mode=16\>" /boot/config.txt; then echo "hdmi_mode=16" >> /boot/config.txt; preinstall_reboot=1; fi
			fi
		elif [ "${hdmi_type}" = "monitor" ]; then
			if ! grep -q "^hdmi_group=2\>" /boot/config.txt; then echo "hdmi_group=2" >> /boot/config.txt; preinstall_reboot=1; fi
			if [ "${hdmi_monitor_res}" = "640x480" ]; then
				if ! grep -q "^hdmi_mode=4\>" /boot/config.txt; then echo "hdmi_mode=4" >> /boot/config.txt; preinstall_reboot=1; fi
			elif [ "${hdmi_monitor_res}" = "800x600" ]; then
				if ! grep -q "^hdmi_mode=9\>" /boot/config.txt; then echo "hdmi_mode=9" >> /boot/config.txt; preinstall_reboot=1; fi
			elif [ "${hdmi_monitor_res}" = "1280x1024" ]; then
				if ! grep -q "^hdmi_mode=35\>" /boot/config.txt; then echo "hdmi_mode=35" >> /boot/config.txt; preinstall_reboot=1; fi
			else
				if ! grep -q "^hdmi_mode=16\>" /boot/config.txt; then echo "hdmi_mode=16" >> /boot/config.txt; preinstall_reboot=1; fi
			fi
		fi
		echo "  == Done. ========================================="
		echo "  =================================================="
	fi
fi
echo "OK"
# Reboot if needed
if [ "${preinstall_reboot}" = "1" ]; then
	echo -e "\n"
	echo "============================="
	echo "== Rebooting in 3 seconds! =="
	echo "============================="
	sleep 3s
	reboot && exit
fi
unset preinstall_reboot

echo
echo -n "Unmounting boot partition... "
umount /boot || fail
echo "OK"

if [ -e "${wlan_configfile}" ]; then
	sanitize_inputfile "${wlan_configfile}"
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
	if [ -z "${drivers_to_load}" ]; then
		drivers_to_load="brcmfmac"
	else
		drivers_to_load="${drivers_to_load},brcmfmac"
	fi
	if [ ! -e "${wlan_configfile}" ]; then
		wlan_configfile=/tmp/wpa_supplicant.conf
		echo "  wlan_ssid = ${wlan_ssid}"
		echo "  wlan_psk = ${wlan_psk}"
		{
			echo "network={"
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
if [ -n "${drivers_to_load}" ]; then
   echo "Loading additional drivers."
   drivers_to_load="$(echo ${drivers_to_load} | tr ',' ' ')"
   for driver in ${drivers_to_load}
   do
	  echo -n "  Loading driver '${driver}'... "
	  modprobe "${driver}" || fail
	  echo "OK"
   done
   echo "Finished loading additional drivers"
   echo
fi

echo -n "Waiting for ${ifname}... "
for i in $(seq 1 10); do
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
		ifconfig "${ifname}" | fgrep addr: | awk '{print $2}' | cut -d: -f2
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
	wget -q -O /online-config.txt "${online_config}" &>/dev/null || fail
	echo "OK"

	echo -n "Executing online-config.txt... "
	sanitize_inputfile /online-config.txt
	source /online-config.txt
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
if [ "${user_is_admin}" = "1" ]; then
	if [ -z "${syspackages}" ]; then
		syspackages="sudo"
	else
		syspackages="${syspackages},sudo"
	fi
fi

# configure different kinds of presets
if [ -z "${cdebootstrap_cmdline}" ]; then

	# from small to large: base, minimal, server
	# not very logical that minimal > base, but that's how it was historically defined

	init_system=""
	if [ "${release}" = "jessie" ]; then
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
	# add user defined packages
	if [ -n "${packages}" ]; then
		custom_packages_postinstall="${custom_packages_postinstall},${packages}"
	fi

	# base
	base_packages="cpufrequtils,kmod,raspbian-archive-keyring"
	base_packages="${custom_packages},${base_packages}"
	base_packages_postinstall=raspberrypi-kernel,raspberrypi-bootloader
	base_packages_postinstall="${custom_packages_postinstall},${base_packages_postinstall}"
	if [ "${init_system}" = "systemd" ]; then
		base_packages="${base_packages},libpam-systemd"
	fi
	if [ "${hwrng_support}" = "1" ]; then
		base_packages="${base_packages},rng-tools"
	fi
	
	# minimal
	minimal_packages="fake-hwclock,ifupdown,net-tools,ntp,openssh-server,dosfstools"
	minimal_packages_postinstall=raspberrypi-sys-mods
	minimal_packages_postinstall="${base_packages_postinstall},${minimal_packages_postinstall}"
	if echo "${ifname}" | grep -q "wlan"; then
		minimal_packages_postinstall="${minimal_packages_postinstall},firmware-brcm80211"
	fi

	# server
	server_packages="vim-tiny,iputils-ping,wget,ca-certificates,rsyslog,cron,dialog,locales,less,man-db,logrotate,bash-completion,console-setup,apt-utils"
	server_packages_postinstall="libraspberrypi-bin,raspi-copies-and-fills"
	server_packages_postinstall="${minimal_packages_postinstall},${server_packages_postinstall}"

	# cleanup package variables
	sanitize_variable base_packages
	sanitize_variable base_packages_postinstall
	sanitize_variable minimal_packages
	sanitize_variable minimal_packages_postinstall
	sanitize_variable server_packages
	sanitize_variable server_packages_postinstall
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
			# this should be 'server', but using '*' for backward-compatibility
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

if [ "${usbboot}" != "1" ]; then
	bootdev=/dev/mmcblk0
	bootpartition=/dev/mmcblk0p1
else
	msd_boot_enabled="$(vcgencmd otp_dump | grep 17: | cut -b 4-5)"
	msd_boot_enabled="$(printf "%s" "${msd_boot_enabled}" | xxd -r -p | xxd -b | cut -d' ' -f2 | cut -b 3)"

	if [ "${msd_boot_enabled}" != "1" ]; then
		echo "================================================================"
		echo "                    !!! IMPORTANT NOTICE !!!"
		echo "Booting from USB mass storage device is disabled!"
		echo "Read the manual to enable it in \"config.txt\"."
		echo
		echo "For this reason, only the system is installed on the USB device!"
		echo
		echo "The installation will continue in 15 seconds..."
		echo "================================================================"
		usbboot=0
		sleep 15s
	else
		echo "Booting from USB mass storage device is enabled."
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
	echo
	usbroot=1
fi

if [ "${usbroot}" = "1" ]; then
	rootdev=/dev/sda
	echo -n "Loading USB modules... "
	modprobe sd_mod &> /dev/null || fail
	modprobe usb-storage &> /dev/null || fail
	echo "OK"
fi

if [ -z "${rootpartition}" ]; then
	if [ "${rootdev}" = "/dev/sda" ]; then
		if [ "${usbboot}" != "1" ]; then
			rootpartition=/dev/sda1
		else
			rootpartition=/dev/sda2
		fi
	else
		rootpartition=/dev/mmcblk0p2
	fi
fi

# sanitize_variables
sanitize_variable locales

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

# show resulting variables
echo
echo "Installer configuration:"
echo "  preset = ${preset}"
echo "  packages = ${packages}"
echo "  firmware_packages = ${firmware_packages}"
echo "  mirror = ${mirror}"
echo "  release = ${release}"
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
echo "  user_is_admin = ${user_is_admin}"
echo "  cdebootstrap_cmdline = ${cdebootstrap_cmdline}"
echo "  packages_postinstall = ${packages_postinstall}"
echo "  boot_volume_label = ${boot_volume_label}"
echo "  bootsize = ${bootsize}"
echo "  bootoffset = ${bootoffset}"
echo "  rootsize = ${rootsize}"
echo "  timeserver = ${timeserver}"
echo "  timezone = ${timezone}"
echo "  keyboard_layout = ${keyboard_layout}"
echo "  locales = ${locales}"
echo "  system_default_locale = ${system_default_locale}"
echo "  wlan_country = ${wlan_country}"
echo "  cmdline = ${cmdline}"
echo "  drivers_to_load = ${drivers_to_load}"
echo "  gpu_mem = ${gpu_mem}"
echo "  hdmi_type = ${hdmi_type}"
echo "  hdmi_tv_res = ${hdmi_tv_res}"
echo "  hdmi_monitor_res = ${hdmi_monitor_res}"
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
echo "  spi_enable = ${spi_enable}"
echo "  i2c_enable = ${i2c_enable}"
echo "  i2c_baudrate = ${i2c_baudrate}"
echo "  sound_enable = ${sound_enable}"
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
	if fdisk -l "${rootdev}" 2>&1 | fgrep Disk | sed 's/^/  /'; then
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
cp -r -- /bootfs/* /boot || fail
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
eval cdebootstrap-static --arch=armhf "${cdebootstrap_cmdline}" "${release}" /rootfs "${mirror}" --keyring=/usr/share/keyrings/raspbian-archive-keyring.gpg 2>&1 | output_filter | sed 's/^/  /'
cdebootstrap_exitcode="${PIPESTATUS[0]}"
if [ "${cdebootstrap_exitcode}" -ne 0 ]; then
	echo
	echo "  ERROR: ${cdebootstrap_exitcode}"
	fail
fi

echo
echo "Configuring installed system:"
# configure root login
if [ -n "${rootpw}" ]; then
	echo -n "  Setting root password... "
	echo -n "root:${rootpw}" | chroot /rootfs /usr/sbin/chpasswd || fail
	echo "OK"
fi
# add SSH key for root (if provided)
if [ -n "${root_ssh_pubkey}" ]; then
	echo -n "  Setting root SSH key... "
	if mkdir -p /rootfs/root/.ssh && chmod 700 /rootfs/root/.ssh; then
		echo "${root_ssh_pubkey}" > /rootfs/root/.ssh/authorized_keys
	else
		fail
	fi
	echo "OK"
	echo -n "  Setting permissions on root SSH authorized_keys... "
	chmod 600 /rootfs/root/.ssh/authorized_keys || fail
	echo "OK"
fi
# openssh-server in jessie doesn't allow root to login with a password
if [ "${root_ssh_pwlogin}" = "1" ]; then
	if [ "${release}" = "jessie" ] && [ -f /rootfs/etc/ssh/sshd_config ]; then
		echo -n "  Allowing root to login with password on jessie... "
		sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /rootfs/etc/ssh/sshd_config || fail
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
		echo -n "  Setting SSH key for '${username}'... "
		ssh_dir="/rootfs/home/${username}/.ssh"
		if mkdir -p "${ssh_dir}" && chmod 700 "${ssh_dir}"; then
			echo "${user_ssh_pubkey}" > "${ssh_dir}/authorized_keys"
		else
			fail
		fi
		echo "OK"
		echo -n "  Setting owner as '${username}' on SSH directory... "
		chroot /rootfs /bin/chown -R "${username}:${username}" "/home/${username}/.ssh" || fail
		echo "OK"
		echo -n "  Setting permissions on ${username} SSH authorized_keys... "
		chmod 600 "${ssh_dir}/authorized_keys" || fail
		echo "OK"
	fi
	if [ -n "${userpw}" ]; then
		echo -n "  Setting password for '${username}'... "
		echo -n "${username}:${userpw}" | chroot /rootfs /usr/sbin/chpasswd || fail
		echo "OK"
	fi
	if [ "${usergpio}" = "1" ]; then
		usersysgroups="${usersysgroups},gpio"
	fi
	if [ "${usergpu}" = "1" ]; then
		usersysgroups="${usersysgroups},video"
	fi
	if [ -n "${usersysgroups}" ]; then
		echo -n "  Adding '${username}' to system groups: "
		usersysgroups="$(echo ${usersysgroups} | tr ',' ' ')"
		for sysgroup in ${usersysgroups}; do
			echo -n "${sysgroup}... "
			chroot /rootfs /usr/sbin/groupadd -fr "${sysgroup}" || fail
			chroot /rootfs /usr/sbin/usermod -aG "${sysgroup}" "${username}" || fail
		done
		echo "OK"
	fi
	if [ -n "${usergroups}" ]; then
		echo -n "  Adding '${username}' to groups: "
		usergroups="$(echo ${usergroups} | tr ',' ' ')"
		for usergroup in ${usergroups}; do
			echo -n "${usergroup} "
			chroot /rootfs /usr/sbin/groupadd -f "${usergroup}" || fail
			chroot /rootfs /usr/sbin/usermod -aG "${usergroup}" "${username}" || fail
		done
		echo "OK"
	fi
	if [ "${user_is_admin}" = "1" ]; then
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
echo -n "  Configuring network settings... "
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

if [ "${disable_predictable_nin}" = "1" ]; then
	# as described here: https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames
	# adding net.ifnames=0 to /boot/cmdline and disabling the persistent-net-generator.rules
	cmdline="${cmdline} net.ifnames=0"
	ln -s /dev/null /rootfs/etc/udev/rules.d/75-persistent-net-generator.rules
fi

if [ "${ip_addr}" != "dhcp" ]; then
	cp /etc/resolv.conf /rootfs/etc/ || fail
fi

echo "OK"

# set timezone and reconfigure tzdata package
echo -n "  Configuring tzdata, setting timezone to ${timezone}... "
echo "${timezone}" > /rootfs/etc/timezone
if chroot /rootfs /usr/sbin/dpkg-reconfigure -f noninteractive tzdata &> /dev/null; then
	echo "OK"
else
	echo "FAILED !"
fi

# generate locale data
if [ -n "${locales}" ]; then
	echo -n "  Enabling locales... "
	sanitize_variable locales
	locales="$(echo "${locales}" | tr ',' ' ')"
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

# there is no hw clock on rpi
if grep -q "#HWCLOCKACCESS=yes" /rootfs/etc/default/hwclock; then
	sed -i "s/^#\(HWCLOCKACCESS=\)yes/\1no/" /rootfs/etc/default/hwclock
elif grep -q "HWCLOCKACCESS=yes" /rootfs/etc/default/hwclock; then
	sed -i "s/^\(HWCLOCKACCESS=\)yes/\1no/m" /rootfs/etc/default/hwclock
else
	echo -e "HWCLOCKACCESS=no\n" >> /rootfs/etc/default/hwclock
fi

# copy apt's sources.list to the target system
echo "Configuring apt:"
echo -n "  Configuring Raspbian repository... "
if [ -e "/bootfs/raspberrypi-ua-netinst/config/apt/sources.list" ]; then
	sed "s/__RELEASE__/${release}/g" "/bootfs/raspberrypi-ua-netinst/config/apt/sources.list" > "/rootfs/etc/apt/sources.list" || fail
	cp /bootfs/raspberrypi-ua-netinst/config/apt/sources.list /rootfs/etc/apt/sources.list || fail
else
	sed "s/__RELEASE__/${release}/g" "/opt/raspberrypi-ua-netinst/res/etc/apt/sources.list" > "/rootfs/etc/apt/sources.list" || fail
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
	sed "s/__RELEASE__/${release}/g" "/bootfs/raspberrypi-ua-netinst/config/apt/raspberrypi.org.list" > "/rootfs/etc/apt/sources.list.d/raspberrypi.org.list" || fail
else
	sed "s/__RELEASE__/${release}/g" "/opt/raspberrypi-ua-netinst/res/etc/apt/raspberrypi.org.list" > "/rootfs/etc/apt/sources.list.d/raspberrypi.org.list" || fail
fi
echo "OK"
echo -n "  Configuring RaspberryPi preference... "
if [ -e "/bootfs/raspberrypi-ua-netinst/config/apt/archive_raspberrypi_org.pref" ]; then
	sed "s/__RELEASE__/${release}/g" "/bootfs/raspberrypi-ua-netinst/config/apt/archive_raspberrypi_org.pref" > "/rootfs/etc/apt/preferences.d/archive_raspberrypi_org.pref" || fail
else
	sed "s/__RELEASE__/${release}/g" "/opt/raspberrypi-ua-netinst/res/etc/apt/archive_raspberrypi_org.pref" > "/rootfs/etc/apt/preferences.d/archive_raspberrypi_org.pref" || fail
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
		sed "s/__RELEASE__/${release}/g" "${listfile}" > "/rootfs/etc/apt/sources.list.d/${listfile}" || fail
		echo "OK"
	fi
done

# iterate through all the *.pref files and add them to /etc/apt/preferences.d
for preffile in ./*.pref
do
	if [ "${listfile}" != "./archive_raspberrypi_org.pref" ] && [ -e "${preffile}" ]; then
		echo -n "  Copying '${preffile}' to /etc/apt/preferences.d/... "
		sed "s/__RELEASE__/${release}/g" "${preffile}" > "/rootfs/etc/apt/preferences.d/${preffile}" || fail
		echo "OK"
	fi
done

# iterate through all the *.key files and add them to apt-key
for keyfile in ./*.key
do
	if [ -e "${keyfile}" ]; then
		echo -n "  Adding key '${keyfile}' to apt."
		(chroot /rootfs /usr/bin/apt-key add -) < "${keyfile}" || fail
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

# return to the old location for the rest of the processing
cd "${old_dir}" || fail

echo
echo -n "Updating package lists... "
for i in $(seq 1 3); do
	if chroot /rootfs /usr/bin/apt-get update &>/dev/null ; then
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
		packages_postinstall="$(echo "${packages_postinstall}" | tr ',' ' ')"
	fi

	DEBIAN_FRONTEND=noninteractive
	export DEBIAN_FRONTEND

	echo
	echo "Downloading packages..."
	for i in $(seq 1 3); do
		eval chroot /rootfs /usr/bin/apt-get -y -d install "${packages_postinstall}" 2>&1 | output_filter | sed 's/^/  /'
		download_exitcode="${PIPESTATUS[0]}"
		if [ "${download_exitcode}" -eq 0 ]; then
			echo "OK"
			break
		else
			if [ "${i}" -eq 3 ]; then
				echo "ERROR: ${download_exitcode}, FAILED !"
				fail
			else
				echo -n "ERROR: ${download_exitcode}, trying again ($((i+1))/3)... "
			fi
		fi
	done

	echo
	echo "Installing kernel, bootloader (=firmware) and user packages..."
	eval chroot /rootfs /usr/bin/apt-get -y install "${packages_postinstall}" 2>&1 | output_filter | sed 's/^/  /'
	if [ "${PIPESTATUS[0]}" -eq 0 ]; then
		echo "OK"
	else
		echo "FAILED !"
	fi
	
	unset DEBIAN_FRONTEND
fi

# (conditionaly) enable hardware watchdog and set up systemd to use it
if [ "${enable_watchdog}" = "1" ]; then
	echo "bcm2708_wdog" >> /rootfs/etc/modules
	sed -i 's/^.*RuntimeWatchdogSec=.*$/RuntimeWatchdogSec=14s/' /rootfs/etc/systemd/system.conf
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

# default cmdline.txt
echo -n "Creating default cmdline.txt... "
if [ "${quiet_boot}" = "1" ]; then
	echo "${cmdline} root=${rootpartition} rootfstype=${rootfstype} rootwait quiet logo.nologo" > /rootfs/boot/cmdline.txt
else
	echo "${cmdline} root=${rootpartition} rootfstype=${rootfstype} rootwait loglevel=3" > /rootfs/boot/cmdline.txt
fi
echo "OK"

# enable spi if specified in the configuration file
if [ "${spi_enable}" = "1" ]; then
	sed -i "s/^#\(dtparam=spi=on\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^dtparam=spi=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
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

# set wlan country code
if [ -n "${wlan_country}" ] && ! grep -q "country=" /rootfs/etc/wpa_supplicant/wpa_supplicant.conf; then
	sanitize_inputfile /rootfs/etc/wpa_supplicant/wpa_supplicant.conf
	echo "country=${wlan_country}" >> /rootfs/etc/wpa_supplicant/wpa_supplicant.conf
fi

# set hdmi options
if [ "${hdmi_type}" = "tv" ] || [ "${hdmi_type}" = "monitor" ]; then
	sed -i "s/^#\(hdmi_ignore_edid=0xa5000080\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^hdmi_ignore_edid=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
		sed -i "s/^\(hdmi_ignore_edid=.*\)/#\1/" /rootfs/boot/config.txt
		echo "hdmi_ignore_edid=0xa5000080" >> /rootfs/boot/config.txt
	fi
	sed -i "s/^#\(hdmi_drive=2\)/\1/" /rootfs/boot/config.txt
	if [ "$(grep -c "^hdmi_drive=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
		sed -i "s/^\(hdmi_drive=.*\)/#\1/" /rootfs/boot/config.txt
		echo "hdmi_drive=2" >> /rootfs/boot/config.txt
	fi
	if [ "${hdmi_type}" = "tv" ]; then
		sed -i "s/^#\(hdmi_group=1\)/\1/" /rootfs/boot/config.txt
		if [ "$(grep -c "^hdmi_group=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
			sed -i "s/^\(hdmi_group=.*\)/#\1/" /rootfs/boot/config.txt
			echo "hdmi_group=1" >> /rootfs/boot/config.txt
		fi
		if [ "${hdmi_tv_res}" = "720p" ]; then
			#hdmi_mode=4 720p@60Hz
			sed -i "s/^#\(hdmi_mode=4\)/\1/" /rootfs/boot/config.txt
			if [ "$(grep -c "^hdmi_mode=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
				sed -i "s/^\(hdmi_mode=.*\)/#\1/" /rootfs/boot/config.txt
				echo "hdmi_mode=4" >> /rootfs/boot/config.txt
			fi
		elif [ "${hdmi_tv_res}" = "1080i" ]; then
			#hdmi_mode=5 1080i@60Hz
			sed -i "s/^#\(hdmi_mode=5\)/\1/" /rootfs/boot/config.txt
			if [ "$(grep -c "^hdmi_mode=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
				sed -i "s/^\(hdmi_mode=.*\)/#\1/" /rootfs/boot/config.txt
				echo "hdmi_mode=5" >> /rootfs/boot/config.txt
			fi
		else
			#hdmi_mode=16 1080p@60Hz
			sed -i "s/^#\(hdmi_mode=16\)/\1/" /rootfs/boot/config.txt
			if [ "$(grep -c "^hdmi_mode=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
				sed -i "s/^\(hdmi_mode=.*\)/#\1/" /rootfs/boot/config.txt
				echo "hdmi_mode=16" >> /rootfs/boot/config.txt
			fi
		fi
	elif [ "${hdmi_type}" = "monitor" ]; then
		sed -i "s/^#\(hdmi_group=2\)/\1/" /rootfs/boot/config.txt
		if [ "$(grep -c "^hdmi_group=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
			sed -i "s/^\(hdmi_group=.*\)/#\1/" /rootfs/boot/config.txt
			echo "hdmi_group=2" >> /rootfs/boot/config.txt
		fi
		if [ "${hdmi_monitor_res}" = "640x480" ]; then
			#hdmi_mode=4 640x480@60Hz
			sed -i "s/^#\(hdmi_mode=4\)/\1/" /rootfs/boot/config.txt
			if [ "$(grep -c "^hdmi_mode=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
				sed -i "s/^\(hdmi_mode=.*\)/#\1/" /rootfs/boot/config.txt
				echo "hdmi_mode=4" >> /rootfs/boot/config.txt
			fi
		elif [ "${hdmi_monitor_res}" = "800x600" ]; then
			#hdmi_mode=9 800x600@60Hz
			sed -i "s/^#\(hdmi_mode=9\)/\1/" /rootfs/boot/config.txt
			if [ "$(grep -c "^hdmi_mode=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
				sed -i "s/^\(hdmi_mode=.*\)/#\1/" /rootfs/boot/config.txt
				echo "hdmi_mode=9" >> /rootfs/boot/config.txt
			fi
		elif [ "${hdmi_monitor_res}" = "1280x1024" ]; then
			#hdmi_mode=35 1280x1024@60Hz
			sed -i "s/^#\(hdmi_mode=35\)/\1/" /rootfs/boot/config.txt
			if [ "$(grep -c "^hdmi_mode=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
				sed -i "s/^\(hdmi_mode=.*\)/#\1/" /rootfs/boot/config.txt
				echo "hdmi_mode=35" >> /rootfs/boot/config.txt
			fi
		else
			#hdmi_mode=16 1024x768@60Hz
			sed -i "s/^#\(hdmi_mode=16\)/\1/" /rootfs/boot/config.txt
			if [ "$(grep -c "^hdmi_mode=.*" /rootfs/boot/config.txt)" -ne 1 ]; then
				sed -i "s/^\(hdmi_mode=.*\)/#\1/" /rootfs/boot/config.txt
				echo "hdmi_mode=16" >> /rootfs/boot/config.txt
			fi
		fi
	fi
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
	sanitize_inputfile /bootfs/raspberrypi-ua-netinst/config/post-install.txt
	source /bootfs/raspberrypi-ua-netinst/config/post-install.txt
	echo "=== Finished executing post-install.txt. ==="
	echo "================================================="
fi

# remove cdebootstrap-helper-rc.d which prevents rc.d scripts from running
echo -n "Removing cdebootstrap-helper-rc.d... "
chroot /rootfs /usr/bin/dpkg -r cdebootstrap-helper-rc.d &>/dev/null || fail
echo "OK"

# save current time if fake-hwclock
echo "Saving current time for fake-hwclock..."
sync # synchronize before saving time to make it "more accurate"
date +"%Y-%m-%d %H:%M:%S" > /rootfs/etc/fake-hwclock.data

ENDTIME=$(date +%s)
DURATION=$((ENDTIME - REAL_STARTTIME))
echo
echo -n "Installation finished at $(date --date="@${ENDTIME}" --utc)"
echo " and took $((DURATION/60)) min $((DURATION%60)) sec (${DURATION} seconds)"

# copy logfile to standard log directory
sleep 1
cp -- "${LOGFILE}" /rootfs/var/log/raspberrypi-ua-netinst.log
chmod 0640 /rootfs/var/log/raspberrypi-ua-netinst.log

echo -n "Unmounting filesystems... "

umount /rootfs/boot
umount /rootfs
echo "OK"

case ${final_action} in
	poweroff)
		echo -n "Finished! Powering off in 5 seconds..."
		;;
	halt)
		echo -n "Finished! Halting in 5 seconds..."
		;;
	*)
		echo -n "Finished! Rebooting to installed system in 5 seconds..."
		final_action=reboot
esac

for i in $(seq 5 -1 1); do
	sleep 1

	echo -n "${i}.. "
done
echo " now"
${final_action}
