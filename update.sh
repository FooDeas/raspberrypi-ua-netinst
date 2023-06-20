#!/usr/bin/env bash
# shellcheck source=./build.conf
# shellcheck disable=SC1091

ARCHIVE_KEYS=()
ARCHIVE_KEYS+=("https://archive.raspbian.org;raspbian.public.key;A0DA38D0D76E8B5D638872819165938D90FDDD2E")
ARCHIVE_KEYS+=("https://archive.raspberrypi.org/debian;raspberrypi.gpg.key;CF8A1AF502A2AA2D763BAE7E82B129927FA3303E")
ARCHIVE_KEYS+=("https://ftp-master.debian.org/keys;archive-key-10.asc;80D15823B7FD1561F9F7BCDDDC30D7C23CBBABEE")
ARCHIVE_KEYS+=("https://ftp-master.debian.org/keys;archive-key-11.asc;1F89983E0081FDE018F3CC9673A4F27B8DD47936")
ARCHIVE_KEYS+=("https://ftp-master.debian.org/keys;release-11.asc;A4285295FC7B1A81600062A9605C66F00D6C9793")

mirror_raspbian=http://mirrordirector.raspbian.org/raspbian
mirror_raspberrypi=http://archive.raspberrypi.org/debian
mirror_debian=http://deb.debian.org/debian
declare mirror_raspbian_cache
declare mirror_raspberrypi_cache
declare mirror_debian_cache
release=bullseye

packages=()

# programs
packages+=("raspberrypi-bootloader")
packages+=("raspberrypi-kernel")
packages+=("firmware-brcm80211")
packages+=("btrfs-progs")
packages+=("busybox")
packages+=("bash-static")
packages+=("cdebootstrap-static")
packages+=("coreutils")
packages+=("diffutils")
packages+=("dosfstools")
packages+=("dpkg")
packages+=("libext2fs2")
packages+=("e2fsprogs")
packages+=("f2fs-tools")
packages+=("gpgv")
packages+=("ifupdown")
packages+=("iproute2")
packages+=("lsb-base")
packages+=("netbase")
packages+=("netcat-openbsd")
packages+=("ntpdate")
packages+=("raspbian-archive-keyring")
packages+=("debian-archive-keyring")
packages+=("rng-tools5")
packages+=("tar")
packages+=("fdisk")
packages+=("util-linux")
packages+=("wpasupplicant")
packages+=("libraspberrypi-bin")
packages+=("xxd")
packages+=("curl")
packages+=("logsave")

# libraries
packages+=("libacl1")
packages+=("libattr1")
packages+=("libblkid1")
packages+=("libbpf0")
packages+=("libbrotli1")
packages+=("libbsd0")
packages+=("libbz2-1.0")
packages+=("libc-bin")
packages+=("libc6")
packages+=("libcap2")
packages+=("libcom-err2")
packages+=("libcurl4")
packages+=("libdb5.3")
packages+=("libdbus-1-3")
packages+=("libelf1")
packages+=("libfdisk1")
packages+=("libffi7")
packages+=("libgcc-s1")
packages+=("libgcrypt20")
packages+=("libgmp10")
packages+=("libgnutls30")
packages+=("libgpg-error0")
packages+=("libgssapi-krb5-2")
packages+=("libhogweed6")
packages+=("libidn2-0")
packages+=("libk5crypto3")
packages+=("libkeyutils1")
packages+=("libkrb5-3")
packages+=("libkrb5support0")
packages+=("libldap-2.4-2")
packages+=("liblz4-1")
packages+=("liblzma5")
packages+=("libmd0")
packages+=("libmount1")
packages+=("libmnl0")
packages+=("libnettle8")
packages+=("libnghttp2-14")
packages+=("libnl-3-200")
packages+=("libnl-genl-3-200")
packages+=("libnl-route-3-200")
packages+=("libpcre2-8-0")
packages+=("libpcsclite1")
packages+=("libp11-kit0")
packages+=("libpsl5")
packages+=("libraspberrypi0")
packages+=("librtmp1")
packages+=("libsasl2-2")
packages+=("libselinux1")
packages+=("libsmartcols1")
packages+=("libss2")
packages+=("libssh2-1")
packages+=("libssl1.1")
packages+=("libsystemd0")
packages+=("libtasn1-6")
packages+=("libtinfo6")
packages+=("libunistring2")
packages+=("libuuid1")
packages+=("libxtables12")
packages+=("libzstd1")
packages+=("zlib1g")


packages_debs=
packages_sha256=

download_file() {
	local download_source=$1
	local download_target=$2
	local progress_option
	if wget --show-progress --version &> /dev/null; [ "${?}" -eq 2 ]; then
	    progress_option=()
	else
	    progress_option=("--show-progress")
	fi
	if [ -z "${download_target}" ]; then
		for i in $(seq 1 5); do
			if ! wget "${progress_option[@]}" -q --no-cache "${download_source}"; then
				if [ "${i}" != "5" ]; then
					sleep 5
				else
					echo -e "ERROR\nDownloading file '${download_source}' failed! Exiting."
					exit 1
				fi
			else
				break
			fi
		done
	else
		for i in $(seq 1 5); do
			if ! wget "${progress_option[@]}" -q --no-cache -O "${download_target}" "${download_source}"; then
				if [ "${i}" != "5" ]; then
					sleep 5
				else
					echo -e "ERROR\nDownloading file '${download_source}' failed! Exiting."
					exit 1
				fi
			else
				break
			fi
		done
	fi
}

check_key() {
	# param 1 = keyfile
	# param 2 = key fingerprint

	# check input parameters
	if [ -z "${1}" ] || [ ! -f "${1}" ]; then
		echo "Parameter 1 of check_key() is not a file!"
		return 1
	fi

	if [ -z "${2}" ]; then
		echo "Parameter 2 of check_key() is not a key fingerprint!"
		return 1
	fi

	KEY_FILE="$1"
	KEY_FINGERPRINT="$2"

	echo -n "Checking key file '${KEY_FILE}'... "

	# check that there is only 1 public key in the key file
	if [ ! "$(gpg --quiet --homedir gnupg --keyid-format long --with-fingerprint --with-colons "${KEY_FILE}" | grep -c "^pub:")" -eq 1 ]; then
		echo "FAILED!"
		echo "There are zero or more than one keys in the ${KEY_FILE} key file!"
		return 1
	fi

	# check that the key file's fingerprint is correct
	if [ "$(gpg --quiet --homedir gnupg --keyid-format long --with-fingerprint --with-colons "${KEY_FILE}" | grep ^fpr: | awk -F: '{print $10}')" != "${KEY_FINGERPRINT}" ]; then
		echo "FAILED!"
		echo "Bad GPG key fingerprint for ${KEY_FILE}!"
		return 1
	fi

	echo "OK"
	return 0
}

setup_archive_keys() {

	mkdir -m 0700 -p gnupg
	# Let gpg set itself up already in the 'gnupg' dir before we actually use it
	echo "Setting up gpg... "
	gpg --homedir gnupg --list-secret-keys

	for archive_key in ${ARCHIVE_KEYS[@]}; do
		echo ""
		IFS=';' read -r KEY_URL KEY_FILE KEY_FINGERPRINT <<< "$archive_key"
		echo "Downloading ${KEY_FILE}."
		download_file ${KEY_URL}/${KEY_FILE}
		if check_key "${KEY_FILE}" "${KEY_FINGERPRINT}"; then
			# GPG key checks out, thus import it into our own keyring
			echo -n "Importing '${KEY_FILE}' into keyring... "
			if gpg -q --homedir gnupg --import "${KEY_FILE}"; then
				echo "OK"
			else
				echo "FAILED!"
				return 1
			fi
		else
			return 1
		fi
	done

	return 0
}

unset_required() {
	for i in "${!packages[@]}"; do
		[[ ${packages[$i]} = "${1}" ]] && unset "packages[$i]" && return 0
	done
	return 1
}

allfound() {
	[[ ${#packages[@]} -eq 0 ]] && return 0
	return 1
}

filter_package_list() {
	grep -E 'Package:|Filename:|SHA256:|^$'
}

download_package_list() {
	# Download and verify package list for $package_section, then add to Packages file
	# Assume that the repository's base Release file is present

	extensions=( '.xz' '.bz2' '.gz' '' )
	for extension in "${extensions[@]}"; do

		# Check that this extension is available
		if grep -q "${package_section}/binary-armhf/Packages${extension}" "${1}_Release"; then

			# Download Packages file
			echo -e "\nDownloading ${package_section} package list..."
			if ! download_file "${2}/dists/$release/$package_section/binary-armhf/Packages${extension}" "tmp${extension}"; then
				echo -e "ERROR\nDownloading '${package_section}' package list failed! Exiting."
				cd ..
				exit 1
			fi

			# Verify the checksum of the Packages file, assuming that the last checksums in the Release file are SHA256 sums
			echo -n "Verifying ${package_section} package list... "
			if [ "$(grep "${package_section}/binary-armhf/Packages${extension}" "${1}_Release" | tail -n1 | awk '{print $1}')" = \
				 "$(sha256sum "tmp${extension}" | awk '{print $1}')" ]; then
				echo "OK"
			else
				echo -e "ERROR\nThe checksum of file '${package_section}/binary-armhf/Packages${extension}' doesn't match!"
				cd ..
				exit 1
			fi

			# Decompress the Packages file
			if [ "${extension}" = ".bz2" ]; then
				decompressor="bunzip2 -c "
			elif [ "${extension}" = ".xz" ]; then
				decompressor="xzcat "
			elif [ "${extension}" = ".gz" ]; then
				decompressor="gunzip -c "
			elif [ "${extension}" = "" ]; then
				decompressor="cat "
			fi
			${decompressor} "tmp${extension}" >> "${1}_Packages"
			rm "tmp${extension}"
			break
		fi
	done
}

download_package_lists() {
	echo -e "\nDownloading Release file and its signature..."
	download_file "${2}/dists/$release/Release" "${1}_Release"
	download_file "${2}/dists/$release/Release.gpg" "${1}_Release.gpg"
	echo -n "Verifying Release file... "
	if gpg --homedir gnupg --verify "${1}_Release.gpg" "${1}_Release" &> /dev/null; then
		echo "OK"
	else
		echo -e "ERROR\nBroken GPG signature on Release file!"
		cd ..
		exit 1
	fi

	echo -n > "${1}_Packages"
	package_section=firmware
	download_package_list "${1}" "${2}"
	package_section=main
	download_package_list "${1}" "${2}"
	package_section=non-free
	download_package_list "${1}" "${2}"
}

add_packages() {
	echo -e "\nAdding required packages..."
	filter_package_list < "${1}_Packages" >"${1}_Packages.tmp"
	for pkg in "${packages[@]}"; do
		while read -r k v
		do
			if [ "${k}" = "Package:" ]; then
				current_package=${v}
			elif [ "${k}" = "Filename:" ]; then
				current_filename=${v}
			elif [ "${k}" = "SHA256:" ]; then
				current_sha256=${v}
			elif [ "${k}" = "" ]; then
				printf "  %-32s %s\n" "${current_package}" "$(basename "${current_filename}")"
				unset_required "${current_package}"
				packages_debs+=("${2}/${current_filename}")
				packages_sha256+=("${current_sha256}  $(basename "${current_filename}")")
				current_package=
				current_filename=
				current_sha256=
			fi
		done < <(grep -A 3 -m 1 ^Package:\ "$pkg"$ "${1}_Packages.tmp")
	done
}

download_packages() {
	echo -e "\nDownloading packages..."
	for package in "${packages_debs[@]}"; do
		echo -e "Downloading package: '${package}'"
		if ! download_file ${package}; then
			echo -e "ERROR\nDownloading '${package}' failed! Exiting."
			cd ..
			exit 1
		fi
	done

	echo -n "Verifying downloaded packages... "
	printf "%s\n" "${packages_sha256[@]}" > SHA256SUMS
	if sha256sum --quiet -c SHA256SUMS; then
		echo "OK"
	else
		echo -e "ERROR\nThe checksums of the downloaded packages don't match the package lists!"
		cd ..
		exit 1
	fi
}

download_remote_file() {
	if [ "${4}" != "" ]; then
		echo -e "\nDownloading '${4}'..."
	else
		echo -e "\nDownloading '${2}'..."
	fi
	download_file "${1}${2}" "${2}_tmp"
	if [ "${3}" != "" ]; then
		if [[ "${2}" =~ .*\.tar\..* ]]; then
			${3} "${2}_tmp" | tar -x "${4}"
		else
			${3} "${2}_tmp"
		fi
		rm "${2}_tmp"
	else
		mv "${2}_tmp" "${2}"
	fi
}

# Read config
if [ -r ./build.conf ]; then
	source <(tr -d "\015" < ./build.conf)
fi

# Download packages
(
	rm -rf packages/
	mkdir packages && cd packages

	## Add caching proxy if configured
	if [ -n "${mirror_raspbian_cache}" ]; then
		mirror_raspbian=${mirror_raspbian/:\/\//:\/\/${mirror_raspbian_cache}\/}
	fi
	if [ -n "${mirror_raspberrypi_cache}" ]; then
		mirror_raspberrypi=${mirror_raspberrypi/:\/\//:\/\/${mirror_raspberrypi_cache}\/}
	fi
	if [ -n "${mirror_debian_cache}" ]; then
		mirror_debian=${mirror_debian/:\/\//:\/\/${mirror_debian_cache}\/}
	fi

	if ! setup_archive_keys; then
		echo -e "ERROR\nSetting up the archives failed! Exiting."
		cd ..
		exit 1
	fi

	## Download package list
	download_package_lists raspberry ${mirror_raspberrypi}
	download_package_lists raspbian ${mirror_raspbian}
	download_package_lists debian ${mirror_debian}

	## Select packages for download
	packages_debs=()
	packages_sha256=()

	add_packages raspberry ${mirror_raspberrypi}
	add_packages raspbian ${mirror_raspbian}
	add_packages debian ${mirror_debian}
	if ! allfound; then
		echo "ERROR: Unable to find all required packages in package list!"
		echo "Missing packages: '${packages[*]}'"
		exit 1
	fi

	## Download selected packages
	download_packages
) || exit $?

# Download additional resources
(
	mkdir -p res && cd res

	## Download default /boot/config.txt and do default changes
	mkdir -p initramfs/boot
	cd initramfs/boot || exit 1
	download_remote_file https://downloads.raspberrypi.org/raspios_armhf/ "boot.tar.xz" xzcat ./config.txt
	sed -i "s/^\(dtparam=audio=on\)/#\1/" config.txt # disable audio
	{
		echo ""
		echo "[pi3]"
		echo "dtoverlay=disable-bt"
		echo "[pi4]"
		echo "dtoverlay=disable-bt"
		echo ""
		echo "[all]"
		echo "# Add other config parameters below this line."
	} >> config.txt
	chmod 644 config.txt
	cd ../.. || exit 1
) || exit $?
