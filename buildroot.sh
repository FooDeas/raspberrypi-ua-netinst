#!/usr/bin/env bash
# shellcheck source=./buildroot.conf
# shellcheck disable=SC1091

set -e # exit if any command fails

# Set defaults for configurable behavior

# Controls production of a bz2-compressed image
compress_bz2=1

# Controls production of an xz-compressed image
compress_xz=1

# Use 'sudo' for commands which require root privileges
use_sudo=0

# If a configuration file exists, import its settings
if [ -r buildroot.conf ]; then
	source <(tr -d "\015" < buildroot.conf)
fi

if [ "$use_sudo" = "1" ]; then
    SUDO=sudo
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
rm -rf "${build_dir:-build_dir}/mnt/"

# Create image
dd if=/dev/zero of="$image" bs=1M count=128

${SUDO} fdisk "${image}" <<EOF
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
	${SUDO} kpartx -as "${image}"
	${SUDO} mkfs.vfat /dev/mapper/loop0p1
	mkdir ${build_dir}/mnt
	${SUDO} mount /dev/mapper/loop0p1 ${build_dir}/mnt
	${SUDO} cp -r ${build_dir}/bootfs/* ${build_dir}/mnt
	${SUDO} umount ${build_dir}/mnt
	${SUDO} kpartx -d "${image}" || true
	rmdir ${build_dir}/mnt
else
	${SUDO} losetup --find --partscan "${image}"
	LOOP_DEV="$(losetup --associated "${image}" | cut -f1 -d':')"
	${SUDO} mkfs.vfat "${LOOP_DEV}p1"
	mkdir ${build_dir}/mnt
	${SUDO} mount "${LOOP_DEV}p1" ${build_dir}/mnt
	${SUDO} cp -r ${build_dir}/bootfs/* ${build_dir}/mnt
	${SUDO} umount ${build_dir}/mnt
	${SUDO} losetup --detach "${LOOP_DEV}"
	rmdir ${build_dir}/mnt
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
