#!/usr/bin/env bash
# shellcheck disable=SC1090
# shellcheck disable=SC1091

set -e # exit if any command fails
umask 022

build_dir=./build_dir
packages_dir=./packages
resources_dir=./res
scripts_dir=./scripts

# set cleanup=non-empty-value to remove temporary build files
cleanup=1

libs_to_copy=()

# update version and date
version_tag="$(git describe --exact-match --tags HEAD 2> /dev/null || true)"
version_commit="$(git rev-parse --short "@{0}" 2> /dev/null || true)"
if [ -n "${version_tag}" ]; then
	version_info="${version_tag} (${version_commit})"
	zipfile="raspberrypi-ua-netinst-${version_tag}.zip"
elif [ -n "${version_commit}" ]; then
	version_info="${version_commit}"
	zipfile="raspberrypi-ua-netinst-git-${version_commit}.zip"
else
	version_info="unknown"
	zipfile="raspberrypi-ua-netinst-$(date +%Y%m%d).zip"
fi

INSTALL_MODULES+=("kernel/fs/btrfs/btrfs.ko")
INSTALL_MODULES+=("kernel/drivers/scsi/sg.ko")

# defines array with kernel versions
function get_kernels {
	local moduleconf
	mapfile -t moduleconf < <(find tmp/lib/modules/ -type f -name "modules.builtin")
	kernels=()
	for i in "${moduleconf[@]}"; do
		kernels+=("$(dirname "${i/tmp\/lib\/modules\//}")")
	done
}

# copies files replacing "kernel*" with kernel versions in path
function cp_kernelfiles {
	for kernel in "${kernels[@]}"; do
		eval cp --preserve=xattr,timestamps -r "${1//kernel\*/${kernel}}" "${2//kernel\*/${kernel}}" || true
	done
}

# checks if first parameter is contained in the array passed as the second parameter
#   use: contains_element "search_for" "${some_array[@]}" || do_if_not_found
function contains_element {
	local elem
	for elem in "${@:2}"; do [[ "${elem}" == "${1}" ]] && return 0; done
	return 1
}

# expects an array with kernel modules as a parameter, checks each module for dependencies
# and if a dependency isn't already in the $modules array, adds it to it (through a temporary
# local array).
# in addition sets the global $new_count variable to the number of dependencies added, so
# that the newly added dependencies can be checked as well
#   use: check_dependencies "${modules[@]:${index}}"
function check_dependencies {
	# collect the parameters into an array
	mods=("${@}")
	# temp array to hold the newly found dependencies
	local -a new_found
	# temp array to hold the found dependencies for a single module
	local -a deps
	local mod
	local dep
	# iterate over the passed modules
	for mod in "${mods[@]}"; do
		# find the module's dependencies, convert into array
		IFS=" " read -r -a deps <<< "$(grep "^${mod}" "${depmod_file}" | cut -d':' -f2)"
		# iterate over the found dependencies
		for dep in "${deps[@]}"; do
			# check if the dependency is in $modules, if not, add to temp array
			contains_element "${dep}" "${modules[@]}" || new_found+=("${dep}")
		done
	done
	# add the newly found dependencies to the end of the $modules array
	modules+=("${new_found[@]}")
	# set the global variable to the number of newly found dependencies
	new_count=${#new_found[@]}
}

# creates the file passed as an argument and sets permissions
function touch_tempfile {
	[[ -z "${1}" ]] && return 1
	touch "${1}" && chmod 600 "${1}"
	echo "${1}"
}

# creates a temporary file and returns (echos) its filename
#   the function checks for different commands and uses the appropriate one
#   it will fallback to creating a file in /tmp
function create_tempfile {
	local tmp_ptrn
	tmp_ptrn="/tmp/$(basename "${0}").${$}"
	if type mktemp &> /dev/null; then
		mktemp 2> /dev/null || \
			mktemp -t raspberrypi-ua-netinst 2> /dev/null || \
			touch_tempfile "${tmp_ptrn}"
	else
		if type tempfile &> /dev/null; then
			# shellcheck disable=SC2186
			tempfile
		else
			touch_tempfile "${tmp_ptrn}"
		fi
	fi
}

# copy an executable file and add all needed libraries to libs_to_copy array
function cp_executable {
	echo "Copying executable $1"
	cp --preserve=xattr,timestamps "$1" "$2"

	LIB_PATH=("tmp/lib" "tmp/usr/lib")
	libs_todo=("$1")
	while true; do
		while IFS='' read -r line; do needed_libs+=("$line"); done < <(readelf -d "${libs_todo[0]}" 2>/dev/null | grep \(NEEDED\) | sed -e 's/.*\[//' -e 's/\]//')
		for lib in "${needed_libs[@]}"; do
			if printf '%s\n' "${libs_to_copy[@]}" | grep -q "/$lib$"; then
				continue
			fi
			echo -n " Adding dependency $lib => "
			lib_found=$(find -L "${LIB_PATH[@]}" -name "$lib" 2>/dev/null | head -n 1)
			if [ -n "$lib_found" ]; then
				echo "$lib_found"
				libs_to_copy+=("$lib_found")
				libs_todo+=("$lib_found")
			else
				echo " not found!"
				exit 1
			fi
		done
		libs_todo=("${libs_todo[@]:1}")
		if [ ${#libs_todo[@]} -eq 0 ]; then
			break
		fi
	done
}

function create_cpio {
	# initialize rootfs
	rm -rf rootfs
	mkdir -p rootfs
	# create all the directories needed to copy the various components into place
	mkdir -p rootfs/bin/
	mkdir -p rootfs/lib/arm-linux-gnueabihf/
	mkdir -p rootfs/lib/lsb/init-functions.d/
	mkdir -p rootfs/etc/{alternatives,cron.daily,default,init,init.d,ld.so.conf.d,logrotate.d,network/if-up.d/}
	mkdir -p rootfs/etc/dpkg/dpkg.cfg.d/
	mkdir -p rootfs/etc/network/{if-down.d,if-post-down.d,if-pre-up.d,if-up.d,interfaces.d}
	mkdir -p rootfs/lib/ifupdown/
	mkdir -p rootfs/lib/lsb/init-functions.d/
	mkdir -p rootfs/lib/modules/
	mkdir -p rootfs/sbin/
	mkdir -p rootfs/usr/bin/
	mkdir -p rootfs/usr/lib/arm-linux-gnueabihf/
	mkdir -p rootfs/usr/sbin/
	mkdir -p rootfs/usr/share/{dpkg,keyrings,libc-bin}
	mkdir -p rootfs/var/lib/dpkg/{alternatives,info,parts,updates}
	mkdir -p rootfs/var/log/
	mkdir -p rootfs/var/run/

	mapfile -t moduleconf < <(find tmp/lib/modules/ -type f -name "modules.order" -o -name "modules.builtin")
	for i in "${moduleconf[@]}"; do
		i="${i/tmp\/}"
		# Copy modules file
		mkdir -p "rootfs/$(dirname "${i}")"
		cp --preserve=xattr,timestamps "tmp/${i}" "rootfs/${i}"
	done

	# calculate module dependencies
	depmod_file=$(create_tempfile)
	for kernel in "${kernels[@]}"; do
		/sbin/depmod -nb tmp "${kernel}" > "${depmod_file}"
	done

	modules=("${INSTALL_MODULES[@]}")

	# new_count contains the number of new elements in the $modules array for each iteration
	new_count=${#modules[@]}
	# repeat the hunt for dependencies until no new ones are found (the loop takes care
	# of finding nested dependencies)
	until [ "${new_count}" == 0 ]; do
		# check the dependencies for the modules in the last $new_count elements
		check_dependencies "${modules[@]:$((${#modules[@]}-new_count))}"
	done

	# do some cleanup
	rm -f "${depmod_file}"

	# copy the needed kernel modules to the rootfs (create directories as needed)
	for module in "${modules[@]}"; do
		# calculate the target dir, just so the following line of code is shorter :)
		for kernel in "${kernels[@]}"; do
			if [ -e "tmp/lib/modules/${kernel}/${module}" ]; then
				dstdir="rootfs/lib/modules/${kernel}/$(dirname "${module}")"
				# check if destination dir exist, create it otherwise
				[ -d "${dstdir}" ] || mkdir -p "${dstdir}"
				cp --preserve=xattr,timestamps -a "tmp/lib/modules/${kernel}/${module}" "${dstdir}"
			fi
		done
	done

	# copy network drivers
	for kernel in "${kernels[@]}"; do
		mkdir -p "rootfs/lib/modules/${kernel}/kernel/drivers/net"
		mkdir -p "rootfs/lib/modules/${kernel}/kernel/net"
	done
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/net/ipv6 rootfs/lib/modules/kernel*/kernel/net/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/net/mac80211 rootfs/lib/modules/kernel*/kernel/net/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/net/rfkill rootfs/lib/modules/kernel*/kernel/net/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/net/wireless rootfs/lib/modules/kernel*/kernel/net/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/net/ethernet rootfs/lib/modules/kernel*/kernel/net/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/net/phy rootfs/lib/modules/kernel*/kernel/net/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/net/usb rootfs/lib/modules/kernel*/kernel/drivers/net/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/net/wireless rootfs/lib/modules/kernel*/kernel/drivers/net/

	# copy i2c drivers
	for kernel in "${kernels[@]}"; do
		mkdir -p "rootfs/lib/modules/${kernel}/kernel/drivers/i2c/busses"
	done
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/i2c/busses/i2c-bcm2708.ko* rootfs/lib/modules/kernel*/kernel/drivers/i2c/busses/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/i2c/busses/i2c-bcm2835.ko* rootfs/lib/modules/kernel*/kernel/drivers/i2c/busses/

	# copy rtc drivers
	for kernel in "${kernels[@]}"; do
		mkdir -p "rootfs/lib/modules/${kernel}/kernel/drivers"
		mkdir -p "rootfs/lib/modules/${kernel}/kernel/drivers/hwmon"
	done
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/rtc rootfs/lib/modules/kernel*/kernel/drivers/
	cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/hwmon/raspberrypi-hwmon.ko* rootfs/lib/modules/kernel*/kernel/drivers/hwmon/

	# create dependency lists
	for kernel in "${kernels[@]}"; do
		/sbin/depmod -b rootfs "${kernel}"
	done

	# install scripts
	cp --preserve=xattr,timestamps -r ../"${scripts_dir}"/* rootfs/
	(cd ../"${scripts_dir}"/ && find . -type d -exec echo rootfs/{} \;) | xargs chmod +rx
	(cd ../"${scripts_dir}"/ && find . -type f -exec echo rootfs/{} \;) | xargs chmod +rx
	sed -i "s/__VERSION__/${version_info}/" rootfs/opt/raspberrypi-ua-netinst/install.sh
	sed -i "s/__DATE__/$(date)/" rootfs/opt/raspberrypi-ua-netinst/install.sh

	# btrfs-progs components
	cp_executable tmp/sbin/mkfs.btrfs rootfs/sbin/

	# busybox components
	cp_executable tmp/bin/busybox rootfs/bin
	cd rootfs && ln -s bin/busybox init; cd ..
	echo -e "\$MODALIAS=.* 0:0 660 @/opt/busybox/bin/modprobe \"\$MODALIAS\"\n(null|zero|full|u?random) 0:0 666" > rootfs/etc/mdev.conf

	# bash-static components
	cp --preserve=xattr,timestamps tmp/bin/bash-static rootfs/bin
	cd rootfs/bin && ln -s bash-static bash; cd ../..

	# cdebootstrap-static components
	cp --preserve=xattr,timestamps -r tmp/usr/share/cdebootstrap-static rootfs/usr/share/
	cp --preserve=xattr,timestamps tmp/usr/bin/cdebootstrap-static rootfs/usr/bin/

	# coreutils components
	cp_executable tmp/bin/cat rootfs/bin/
	cp_executable tmp/bin/chgrp rootfs/bin/
	cp_executable tmp/bin/chmod rootfs/bin/
	cp_executable tmp/bin/chown rootfs/bin/
	cp_executable tmp/bin/cp rootfs/bin/
	cp_executable tmp/bin/date rootfs/bin/
	cp_executable tmp/bin/dd rootfs/bin/
	cp_executable tmp/bin/df rootfs/bin/
	cp_executable tmp/bin/dir rootfs/bin/
	cp_executable tmp/bin/echo rootfs/bin/
	cp_executable tmp/bin/false rootfs/bin/
	cp_executable tmp/bin/ln rootfs/bin/
	cp_executable tmp/bin/ls rootfs/bin/
	cp_executable tmp/bin/mkdir rootfs/bin/
	cp_executable tmp/bin/mknod rootfs/bin/
	cp_executable tmp/bin/mktemp rootfs/bin/
	cp_executable tmp/bin/mv rootfs/bin/
	cp_executable tmp/bin/pwd rootfs/bin/
	cp_executable tmp/bin/readlink rootfs/bin/
	cp_executable tmp/bin/rm rootfs/bin/
	cp_executable tmp/bin/rmdir rootfs/bin/
	cp_executable tmp/bin/sleep rootfs/bin/
	cp_executable tmp/bin/stty rootfs/bin/
	cp_executable tmp/bin/sync rootfs/bin/
	cp_executable tmp/bin/touch rootfs/bin/
	cp_executable tmp/bin/true rootfs/bin/
	cp_executable tmp/bin/uname rootfs/bin/
	cp_executable tmp/bin/vdir rootfs/bin/

	# diffutils components
	cp_executable tmp/usr/bin/cmp rootfs/usr/bin/

	# dosfstools components
	cp_executable tmp/sbin/mkfs.fat rootfs/sbin/
	cd rootfs/sbin
	ln -s mkfs.fat mkfs.vfat
	cd ../..

	# dpkg components
	cp --preserve=xattr,timestamps tmp/etc/alternatives/README rootfs/etc/alternatives/
	cp --preserve=xattr,timestamps tmp/etc/cron.daily/dpkg rootfs/etc/cron.daily/
	cp --preserve=xattr,timestamps tmp/etc/dpkg/dpkg.cfg rootfs/etc/dpkg/
	cp --preserve=xattr,timestamps tmp/etc/logrotate.d/dpkg rootfs/etc/logrotate.d/
	cp_executable tmp/sbin/start-stop-daemon rootfs/sbin/
	cp_executable tmp/usr/bin/dpkg rootfs/usr/bin/
	cp_executable tmp/usr/bin/dpkg-deb rootfs/usr/bin/
	cp_executable tmp/usr/bin/dpkg-divert rootfs/usr/bin/
	cp_executable tmp/usr/bin/dpkg-maintscript-helper rootfs/usr/bin/
	cp_executable tmp/usr/bin/dpkg-query rootfs/usr/bin/
	cp_executable tmp/usr/bin/dpkg-split rootfs/usr/bin/
	cp_executable tmp/usr/bin/dpkg-statoverride rootfs/usr/bin/
	cp_executable tmp/usr/bin/dpkg-trigger rootfs/usr/bin/
	cp_executable tmp/usr/bin/update-alternatives rootfs/usr/bin/
	cp --preserve=xattr,timestamps tmp/usr/share/dpkg/abitable rootfs/usr/share/dpkg/
	cp --preserve=xattr,timestamps tmp/usr/share/dpkg/cputable rootfs/usr/share/dpkg/
	cp --preserve=xattr,timestamps tmp/usr/share/dpkg/ostable rootfs/usr/share/dpkg/
	cp --preserve=xattr,timestamps tmp/usr/share/dpkg/tupletable rootfs/usr/share/dpkg/
	cd rootfs/usr/sbin
	ln -s ../bin/dpkg-divert dpkg-divert
	ln -s ../bin/dpkg-statoverride dpkg-statoverride
	ln -s ../bin/update-alternatives update-alternatives
	cd ../../..
	touch rootfs/var/lib/dpkg/status

	# e2fsprogs components
	cp --preserve=xattr,timestamps tmp/etc/mke2fs.conf rootfs/etc/
	cp_executable tmp/sbin/mke2fs rootfs/sbin/
	cd rootfs/sbin
	ln -s mke2fs mkfs.ext4
	cd ../..

	# f2fs-tools components
	cp_executable tmp/sbin/mkfs.f2fs rootfs/sbin/

	# gpgv components
	cp_executable tmp/usr/bin/gpgv rootfs/usr/bin/

	# ifupdown components
	cp --preserve=xattr,timestamps tmp/etc/default/networking rootfs/etc/default/
	cp --preserve=xattr,timestamps tmp/etc/init.d/networking rootfs/etc/init.d/
	cp --preserve=xattr,timestamps tmp/lib/ifupdown/settle-dad.sh rootfs/lib/ifupdown/
	cp_executable tmp/sbin/ifup rootfs/sbin/
	cd rootfs/sbin
	ln -s ifup ifdown
	ln -s ifup ifquery
	cd ../..

	# iproute2 components
	cp_executable tmp/bin/ip rootfs/bin/

	# sysvinit-utils components
	cp --preserve=xattr,timestamps tmp/lib/lsb/init-functions rootfs/lib/lsb/
	cp --preserve=xattr,timestamps tmp/lib/lsb/init-functions.d/00-verbose rootfs/lib/lsb/init-functions.d/

	# netbase components
	cp --preserve=xattr,timestamps tmp/etc/protocols rootfs/etc/
	cp --preserve=xattr,timestamps tmp/etc/rpc rootfs/etc/
	cp --preserve=xattr,timestamps tmp/etc/services rootfs/etc/

	# netcat-openbsd
	cp_executable tmp/bin/nc.openbsd rootfs/bin/nc

	# raspberrypi.org GPG key
	cp --preserve=xattr,timestamps ../"${packages_dir}"/raspberrypi.gpg.key rootfs/usr/share/keyrings/

	# *-archive-keyring components
	cp --preserve=xattr,timestamps tmp/usr/share/keyrings/*.gpg rootfs/usr/share/keyrings/

	# rng-tools5 components
	cp_executable tmp/usr/sbin/rngd rootfs/usr/sbin/

	# tar components
	cp_executable tmp/bin/tar rootfs/bin/

	# fdisk components
	cp_executable tmp/sbin/fdisk rootfs/sbin/

	# util-linux components
	cp_executable tmp/sbin/blkid rootfs/sbin/
	cp_executable tmp/sbin/mkswap rootfs/sbin/

	# wpasupplicant components
	cp_executable tmp/sbin/wpa_supplicant rootfs/sbin/wpa_supplicant
	cp_executable tmp/usr/bin/wpa_passphrase rootfs/usr/bin/wpa_passphrase
	cp --preserve=xattr,timestamps -r tmp/etc/wpa_supplicant rootfs/etc/wpa_supplicant

	# libc-bin components
	cp --preserve=xattr,timestamps tmp/etc/default/nss rootfs/etc/default/
	cp --preserve=xattr,timestamps tmp/etc/ld.so.conf.d/* rootfs/etc/ld.so.conf.d/
	cp --preserve=xattr,timestamps tmp/etc/bindresvport.blacklist rootfs/etc/
	cp --preserve=xattr,timestamps tmp/etc/gai.conf rootfs/etc/
	cp --preserve=xattr,timestamps tmp/etc/ld.so.conf rootfs/etc/
	cp_executable tmp/sbin/ldconfig rootfs/sbin/
	# lib/locale ?
	cp --preserve=xattr,timestamps tmp/usr/share/libc-bin/nsswitch.conf rootfs/usr/share/libc-bin/

	# libc6 components
	cp_executable tmp/lib/*/libnss_dns.so.* rootfs/lib/arm-linux-gnueabihf/
	cp_executable tmp/lib/*/libnss_files.so.* rootfs/lib/arm-linux-gnueabihf/

	# Binary firmware for version 3 Model B, Zero W wireless
	mkdir -p rootfs/lib/firmware/brcm
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43430-sdio.bin rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43430-sdio.txt rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43430-sdio.clm_blob rootfs/lib/firmware/brcm/

	# Binary firmware for Zero 2 W wireless
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43436-sdio.bin rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43436-sdio.clm_blob rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43436-sdio.txt rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43436s-sdio.bin rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43436s-sdio.txt rootfs/lib/firmware/brcm/

	# Binary firmware for version 3 Model A+/B+, 4 Model B wireless
	ln -s cyfmac43455-sdio-standard.bin tmp/lib/firmware/cypress/cyfmac43455-sdio.bin
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43455-sdio.bin rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43455-sdio.clm_blob rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43455-sdio.txt rootfs/lib/firmware/brcm/

	# Binary firmware for version 4 Compute Module, 400 wireless
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43456-sdio.bin rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43456-sdio.clm_blob rootfs/lib/firmware/brcm/
	cp --preserve=xattr,timestamps tmp/lib/firmware/brcm/brcmfmac43456-sdio.txt rootfs/lib/firmware/brcm/

	# wireless regulatory database information
	cp --preserve=xattr,timestamps tmp/lib/firmware/regulatory.db-debian rootfs/lib/firmware/regulatory.db
	cp --preserve=xattr,timestamps tmp/lib/firmware/regulatory.db.p7s-debian rootfs/lib/firmware/regulatory.db.p7s

	# vcgencmd
	## libraspberrypi-bin
	mkdir -p rootfs/usr/bin
	cp_executable tmp/usr/bin/vcgencmd rootfs/usr/bin/

	# xxd
	mkdir -p rootfs/usr/bin
	cp_executable tmp/usr/bin/xxd rootfs/usr/bin/

	# install additional resources
	mkdir -p rootfs/opt/raspberrypi-ua-netinst/res
	cp --preserve=xattr,timestamps -r ../"${resources_dir}"/initramfs/* rootfs/opt/raspberrypi-ua-netinst/res/
	(cd ../"${resources_dir}"/initramfs/ && find . -type d -exec echo rootfs/opt/raspberrypi-ua-netinst/res/{} \;) | xargs chmod +rx
	(cd ../"${resources_dir}"/initramfs/ && find . -type f -exec echo rootfs/opt/raspberrypi-ua-netinst/res/{} \;) | xargs chmod +r

	# curl
	cp_executable tmp/usr/bin/curl rootfs/usr/bin/

	# copy all libraries needed by executable files above
	for lib in "${libs_to_copy[@]}"; do
		cp --preserve=xattr,timestamps "${lib}" "$(echo "${lib}" | sed -e 's/^tmp\//rootfs\//')"
	done

	INITRAMFS="../raspberrypi-ua-netinst.cpio.gz"
	(cd rootfs && find . | cpio -H newc -ov | gzip --best > $INITRAMFS)

	[ "$cleanup" ] && rm -rf rootfs
}

# Run update if never run
if [ ! -d packages ]; then
	. ./update.sh
fi

# Prepare
rm -rf ${build_dir} && mkdir -p ${build_dir} && cd ${build_dir}
rm -rf tmp && mkdir tmp

# extract debs
echo "Extracting packages..."
for i in ../packages/*.deb; do
	cd tmp && ar x "../${i}" && tar -xf data.tar.*; rm -f data.tar.* control.tar.* debian-binary; cd ..
done

echo "Preparing data and creating cpio..."
# get kernel versions
get_kernels

# initialize bootfs
rm -rf bootfs
mkdir -p bootfs/raspberrypi-ua-netinst

# raspberrypi-bootloader components and kernel
cp --preserve=xattr,timestamps -r tmp/boot/* bootfs/
mv bootfs/kernel*.img bootfs/raspberrypi-ua-netinst/
mv bootfs/*.dtb bootfs/raspberrypi-ua-netinst/
mv bootfs/overlays bootfs/raspberrypi-ua-netinst/

if [ ! -f bootfs/config.txt ] ; then
	touch bootfs/config.txt
fi

create_cpio
mv raspberrypi-ua-netinst.cpio.gz bootfs/raspberrypi-ua-netinst/initramfs.gz

{
	echo "[all]"
	echo "os_prefix=raspberrypi-ua-netinst/"
	echo "initramfs initramfs.gz"
	echo "gpu_mem=16"
	echo "[pi3]"
	echo "dtoverlay=disable-bt"
	echo "arm_64bit=1"
	echo "[pi4]"
	echo "dtoverlay=disable-bt"
	echo "arm_64bit=1"
	echo "[pi02]"
	echo "arm_64bit=1"
	echo "[board-type=a02042]"
	echo "arm_64bit=1"
	echo "[board-type=a22042]"
	echo "arm_64bit=1"
} >> bootfs/raspberrypi-ua-netinst/config.txt

cp bootfs/raspberrypi-ua-netinst/config.txt bootfs/config.txt

echo "consoleblank=0 console=serial0,115200 console=tty1 rootwait" > bootfs/raspberrypi-ua-netinst/cmdline.txt

if [ ! -f bootfs/TIMEOUT ] ; then
	touch bootfs/TIMEOUT
fi

# prepare config content
mkdir -p bootfs/raspberrypi-ua-netinst/config
mkdir -p bootfs/raspberrypi-ua-netinst/config/apt
mkdir -p bootfs/raspberrypi-ua-netinst/config/boot
mkdir -p bootfs/raspberrypi-ua-netinst/config/files
mkdir -p bootfs/raspberrypi-ua-netinst/config/files/root
if [ -d ../config ]; then
	cp --preserve=xattr,timestamps -r ../config/* ./bootfs/raspberrypi-ua-netinst/config/
	find ./bootfs/ -type f -name "*.txt" -execdir sed -i -e 's/\([^\r]\)$/\1\r/' {} +
fi

# create zip file
rm -f "${zipfile}"
cd bootfs && zip -r -9 "../${zipfile}" ./*; cd ..
mv "${zipfile}" ../

# clean up
[ "$cleanup" ] && rm -rf tmp
