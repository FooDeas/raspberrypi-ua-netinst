#!/usr/bin/env bash
# shellcheck disable=SC1090
# shellcheck disable=SC1091

ARCHIVE_KEYS=()
ARCHIVE_KEYS+=("https://archive.raspbian.org;raspbian.public.key;A0DA38D0D76E8B5D638872819165938D90FDDD2E")
ARCHIVE_KEYS+=("https://archive.raspberrypi.org/debian;raspberrypi.gpg.key;CF8A1AF502A2AA2D763BAE7E82B129927FA3303E")
ARCHIVE_KEYS+=("https://ftp-master.debian.org/keys;archive-key-11.asc;1F89983E0081FDE018F3CC9673A4F27B8DD47936")
ARCHIVE_KEYS+=("https://ftp-master.debian.org/keys;release-11.asc;A4285295FC7B1A81600062A9605C66F00D6C9793")
ARCHIVE_KEYS+=("https://ftp-master.debian.org/keys;archive-key-12.asc;B8B80B5B623EAB6AD8775C45B7C5D7D6350947F8")
ARCHIVE_KEYS+=("https://ftp-master.debian.org/keys;release-12.asc;4D64FEC119C2029067D6E791F8D2585B8783D481")

mirror_raspbian=http://mirrordirector.raspbian.org/raspbian
mirror_raspberrypi=http://archive.raspberrypi.org/debian
mirror_debian=http://deb.debian.org/debian
declare mirror_raspbian_cache
declare mirror_raspberrypi_cache
declare mirror_debian_cache
release=bookworm

# set debug_cache=non-empty-value to run this script using cached data in packages/ from a previous run.
debug_cache=

packages=()

# programs
packages+=("raspberrypi-bootloader")
packages+=("raspberrypi-kernel")
packages+=("firmware-brcm80211")
packages+=("wireless-regdb")
packages+=("btrfs-progs")
packages+=("busybox")
packages+=("bash-static")
packages+=("cdebootstrap-static")
packages+=("coreutils")
packages+=("diffutils")
packages+=("dosfstools")
packages+=("dpkg")
packages+=("libc-bin")
packages+=("e2fsprogs")
packages+=("f2fs-tools")
packages+=("gpgv")
packages+=("ifupdown")
packages+=("iproute2")
packages+=("sysvinit-utils")
packages+=("netbase")
packages+=("netcat-openbsd")
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


packages_debs=
packages_sha256=
packages_done=()

download_file() {
	[ "$debug_cache" ] && return
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

	for archive_key in "${ARCHIVE_KEYS[@]}"; do
		echo ""
		IFS=';' read -r KEY_URL KEY_FILE KEY_FINGERPRINT <<< "$archive_key"
		echo "Downloading ${KEY_FILE}."
		download_file "${KEY_URL}/${KEY_FILE}"
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
	grep -E '^Package:|^Pre-Depends:|^Depends:|^Filename:|^SHA256:|^$'
}

download_package_list() {
	# Download and verify package list for $package_section, then add to Packages file
	# Assume that the repository's base Release file is present

	extensions=( '.xz' '.bz2' '.gz' '' )
	for extension in "${extensions[@]}"; do

		# Check that this extension is available
		if grep -q "${package_section}/binary-armhf/Packages${extension}" "${1}_Release"; then

			# Download Packages file
			echo -e "\n${1}: Downloading ${package_section} package list..."
			if ! download_file "${2}/dists/$release/$package_section/binary-armhf/Packages${extension}" "tmp${extension}"; then
				echo -e "ERROR\nDownloading '${package_section}' package list failed! Exiting."
				cd ..
				exit 1
			fi

			# Verify the checksum of the Packages file, assuming that the last checksums in the Release file are SHA256 sums
			echo -n "Verifying ${package_section} package list... "
			if [ "$(grep "${package_section}/binary-armhf/Packages${extension}" "${1}_Release" | tail -n1 | awk '{print $1}')" = "$(sha256sum "tmp${extension}" | awk '{print $1}')" ]; then
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
	echo -e "\n--- ${1} ---\nDownloading Release file and its signature..."
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
	if [ "${1}" != "debian" ]; then
		package_section=firmware
		download_package_list "${1}" "${2}"
	else
		package_section=non-free-firmware
		download_package_list "${1}" "${2}"
	fi
	package_section=main
	download_package_list "${1}" "${2}"
	package_section=non-free
	download_package_list "${1}" "${2}"
}

add_packages() {
	echo -e "\n--- ${1} ---\nAdding required packages..."
	filter_package_list < "${1}_Packages" >"${1}_Packages.tmp"
	while true; do
		libs=()
		for pkg in "${packages[@]}"; do
			current_package=
			current_depends=()
			current_filename=
			current_sha256=
			while read -r k v
			do
				if [ "${k}" = "Package:" ]; then
					current_package=${v}
				elif [ "${k}" = "Pre-Depends:" ]; then
					while IFS='' read -r line; do current_depends+=("$line"); done < <(echo "${v}" | sed -e 's/, /\n/g' -e 's/\ Pre-Depends:\ //' -e 's/ ([^)]*)//g')
				elif [ "${k}" = "Depends:" ]; then
					while IFS='' read -r line; do current_depends+=("$line"); done < <(echo "${v}" | sed -e 's/, /\n/g' -e 's/\ Depends:\ //' -e 's/ ([^)]*)//g')
				elif [ "${k}" = "Filename:" ]; then
					current_filename=${v}
				elif [ "${k}" = "SHA256:" ]; then
					current_sha256=${v}
				elif [ "${k}" = "" ]; then
					break
				fi
			done < <(grep -A 4 -m 1 ^Package:\ "$pkg"$ "${1}_Packages.tmp")
			if [ -z "${current_package}" ]; then # package not found
				continue
			fi
			printf "  %-32s %s\n" "${current_package}" "$(basename "${current_filename}")"
			unset_required "${current_package}"
			packages_debs+=("${2}/${current_filename}")
			packages_sha256+=("${current_sha256}  $(basename "${current_filename}")")
			packages_done+=("${current_package}")
			while IFS='' read -r line; do libs+=("$line"); done < <(printf '%s\n' "${current_depends[@]}" | grep "lib")
		done
		# remove duplicate libs
		mapfile -t libs < <(printf '%s\n' "${libs[@]}" | sort | uniq)
		# remove libs already done
		mapfile -t libs < <(printf '%s\n' "${packages_done[@]}" "${packages_done[@]}" "${libs[@]}" | sort | uniq -u)
		# we're done if no libs to add
		if [ -z "${libs[*]}" ]; then
			break
		fi
		packages+=("${libs[@]}")
		echo -e "\nAdding dependency libraries..."
	done
}

download_packages() {
	echo -e "\nDownloading packages..."
	for package in "${packages_debs[@]}"; do
		echo -e "Downloading package: '${package}'"
		if ! download_file "${package}"; then
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
	[ "$debug_cache" ] && return
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
	if [ ! "$debug_cache" ]; then
		rm -rf packages/
	fi
	mkdir -p packages && cd packages

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
	if [ ! "$debug_cache" ]; then
		download_package_lists raspberry "${mirror_raspberrypi}"
		download_package_lists raspbian "${mirror_raspbian}"
		download_package_lists debian "${mirror_debian}"
	fi

	## Select packages for download
	packages_debs=()
	packages_sha256=()

	add_packages raspberry "${mirror_raspberrypi}"
	add_packages raspbian "${mirror_raspbian}"
	add_packages debian "${mirror_debian}"
	if ! allfound; then
		echo "ERROR: Unable to find all required packages in package list!"
		echo "Missing packages: '${packages[*]}'"
		exit 1
	fi

	## Download selected packages
	if [ ! "$debug_cache" ]; then
		download_packages
	fi
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
