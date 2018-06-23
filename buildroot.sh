#!/usr/bin/env bash

set -e # exit if any command fails

# Set defaults for configurable behavior

# Controls production of a bz2-compressed image
compress_bz2=1

# Controls production of an xz-compressed image
compress_xz=1

# If a configuration file exists, import its settings
if [ -e buildroot.conf ]; then
	# shellcheck disable=SC1091
	source buildroot.conf
fi

build_dir=build_dir

version_tag="$(git describe --exact-match --tags HEAD 2> /dev/null || true)"
version_commit="$(git rev-parse --short "@{0}" 2> /dev/null || true)"
if [ -n "${version_tag}" ]; then
	imagename="raspberrypi-ua-netinst-${version_tag}"
elif [ -n "${version_commit}" ]; then
	imagename="raspberrypi-ua-netinst-git-${version_commit}"
else
	imagename="raspberrypi-ua-netinst-$(date +%Y%m%d)"
fi
export imagename

image=${build_dir}/${imagename}.img

# Prepare
rm -f "${image}"

# Create image
dd if=/dev/zero of="$image" bs=1M count=128

fdisk "${image}" <<EOF
n
p
1


t
b
w
EOF

if ! losetup --version &> /dev/null; then
	losetup_lt_2_22=true
elif [ "$(echo "$(losetup --version | rev|cut -f1 -d' '|rev|cut -d'.' -f-2)"'<'2.22 | bc -l)" -ne 0 ]; then
	losetup_lt_2_22=true
else
	losetup_lt_2_22=false
fi

if [ "$losetup_lt_2_22" = "true" ]; then
	kpartx -as "${image}"
	mkfs.vfat /dev/mapper/loop0p1
	mount /dev/mapper/loop0p1 /mnt
	cp -r ${build_dir}/bootfs/* /mnt/
	umount /mnt
	kpartx -d "${image}" || true
else
	losetup --find --partscan "${image}"
	LOOP_DEV="$(losetup --associated "${image}" | cut -f1 -d':')"
	mkfs.vfat "${LOOP_DEV}p1"
	mount "${LOOP_DEV}p1" /mnt
	cp -r ${build_dir}/bootfs/* /mnt/
	umount /mnt
	losetup --detach "${LOOP_DEV}"
fi

# Create archives

if [ "$compress_xz" = "1" ]; then
	rm -f "${image}.xz"
	if ! xz -9v --keep "${image}"; then
		# This happens e.g. on Raspberry Pi because xz runs out of memory.
		echo "WARNING: Could not create '${IMG}.xz' variant." >&2
	fi
	rm -f "${imagename}.img.xz"
	mv "${image}.xz" ./
fi

if [ "$compress_bz2" = "1" ]; then
	rm -f "${imagename}.img.bz2"
	( bzip2 -9v > "${imagename}.img.bz2" ) < "${image}"
fi

# Cleanup

if [ "$compress_xz" = "1" ] || [ "$compress_bz2" = "1" ]; then
	rm -f "${image}"
fi
