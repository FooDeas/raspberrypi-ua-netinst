#!/usr/bin/env bash

set -e # exit if any command fails

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
rm -f "${build_dir}/${imagename}.img.xz"
if ! xz -9v --keep "${image}"; then
	# This happens e.g. on Raspberry Pi because xz runs out of memory.
	echo "WARNING: Could not create '${IMG}.xz' variant." >&2
fi
rm -f "${imagename}.img.xz"
mv "${image}.xz" ./

rm -f "${imagename}.img.bz2"
( bzip2 -9v > "${imagename}.img.bz2" ) < "${image}"

# Cleanup
rm -f "${image}"
