#!/usr/bin/env bash
# shellcheck disable=SC1091

set -e

INSTALL_MODULES="kernel/fs/btrfs/btrfs.ko"
INSTALL_MODULES="$INSTALL_MODULES kernel/drivers/scsi/sg.ko"

# defines array with kernel versions
function get_kernels {
    local moduleconf
    moduleconf=($(find tmp/lib/modules/ -type f -name "modules.builtin"))
    kernels=()
    for i in "${moduleconf[@]}"; do
        kernels+=("$(dirname "${i/tmp\/lib\/modules\//}")")
    done
}

# copies files replacing "kernel*" with kernel versions in path
function cp_kernelfiles {
    for kernel in "${kernels[@]}"; do
        eval cp -r "${1//kernel\*/${kernel}}" "${2//kernel\*/${kernel}}"
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
        # find the modules dependencies, convert into array
        deps=($(grep "^${mod}" "${depmod_file}" | cut -d':' -f2))
        # iterate over the found dependencies
        for dep in "${deps[@]}"; do
            # check if the dependency is in $modules, if not, add to temp array
            contains_element "${dep}" "${modules[@]}" || new_found[${#new_found[@]}]="${dep}"
        done
    done
    # add the newly found dependencies to the end of the $modules array
    modules=("${modules[@]}" "${new_found[@]}")
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
            tempfile
        else
            touch_tempfile "${tmp_ptrn}"
        fi
    fi
}

function create_cpio {
    # initialize rootfs
    rm -rf rootfs
    mkdir -p rootfs
    # create all the directories needed to copy the various components into place
    mkdir -p rootfs/bin/
    mkdir -p rootfs/lib/arm-linux-gnueabihf/
    mkdir -p rootfs/lib/lsb/init-functions.d/
    mkdir -p rootfs/etc/{alternatives,cron.daily,default,init,init.d,iproute2,ld.so.conf.d,logrotate.d,network/if-up.d/}
    mkdir -p rootfs/etc/dpkg/dpkg.cfg.d/
    mkdir -p rootfs/etc/network/{if-down.d,if-post-down.d,if-pre-up.d,if-up.d,interfaces.d}
    mkdir -p rootfs/lib/ifupdown/
    mkdir -p rootfs/lib/lsb/init-functions.d/
    mkdir -p rootfs/lib/modules/
    mkdir -p rootfs/sbin/
    mkdir -p rootfs/usr/bin/
    mkdir -p rootfs/usr/lib/mime/packages/
    mkdir -p rootfs/usr/lib/openssl-1.0.0/engines/
    mkdir -p rootfs/usr/lib/{tar,tc}
    mkdir -p rootfs/usr/sbin/
    mkdir -p rootfs/usr/share/{dpkg,keyrings,libc-bin}
    mkdir -p rootfs/var/lib/dpkg/{alternatives,info,parts,updates}
    mkdir -p rootfs/var/lib/ntpdate
    mkdir -p rootfs/var/log/
    mkdir -p rootfs/var/run/

    moduleconf=($(find tmp/lib/modules/ -type f -name "modules.order" -o -name "modules.builtin"))
    for i in "${moduleconf[@]}"; do
        i="${i/tmp\/}"
        # Copy modules file
        mkdir -p "rootfs/$(dirname "${i}")"
        cp "tmp/${i}" "rootfs/${i}"
    done

    # calculate module dependencies
    depmod_file=$(create_tempfile)
    for kernel in "${kernels[@]}"; do
        /sbin/depmod -nb tmp "${kernel}" > "${depmod_file}"
    done

    modules=(${INSTALL_MODULES})

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
                cp -a "tmp/lib/modules/${kernel}/${module}" "${dstdir}"
            fi
        done
    done

    # copy network drivers
    for kernel in "${kernels[@]}"; do
        mkdir -p "rootfs/lib/modules/${kernel}/kernel/drivers/net"
        mkdir -p "rootfs/lib/modules/${kernel}/kernel/net"
    done
    cp_kernelfiles tmp/lib/modules/kernel*/kernel/net/mac80211 rootfs/lib/modules/kernel*/kernel/net/
    cp_kernelfiles tmp/lib/modules/kernel*/kernel/net/rfkill rootfs/lib/modules/kernel*/kernel/net/
    cp_kernelfiles tmp/lib/modules/kernel*/kernel/net/wireless rootfs/lib/modules/kernel*/kernel/net/
    cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/net/ethernet rootfs/lib/modules/kernel*/kernel/net/
    cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/net/phy rootfs/lib/modules/kernel*/kernel/net/
    cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/net/usb rootfs/lib/modules/kernel*/kernel/drivers/net/
    cp_kernelfiles tmp/lib/modules/kernel*/kernel/drivers/net/wireless rootfs/lib/modules/kernel*/kernel/drivers/net/

    # create dependency lists
    for kernel in "${kernels[@]}"; do
        /sbin/depmod -b rootfs "${kernel}"
    done

    # install scripts
    cp -r scripts/* rootfs/

    # update version and date
    version_tag="$(git describe --exact-match --tags HEAD 2> /dev/null || true)"
    version_commit="$(git rev-parse --short "@{0}" 2> /dev/null || true)"
    if [ -n "${version_tag}" ]; then
        version_info="${version_tag} (${version_commit})"
    elif [ -n "${version_commit}" ]; then
        version_info="${version_commit}"
    else
        version_info="unknown"
    fi

    sed -i "s/__VERSION__/${version_info}/" rootfs/etc/init.d/rcS
    sed -i "s/__DATE__/$(date)/" rootfs/etc/init.d/rcS


    # btrfs-tools components
    cp tmp/sbin/mkfs.btrfs rootfs/sbin/
    cp tmp/usr/lib/*/libbtrfs.so.0 rootfs/lib/

    # busybox components
    cp tmp/bin/busybox rootfs/bin
    cd rootfs && ln -s bin/busybox init; cd ..
    echo "\$MODALIAS=.* 0:0 660 @/opt/busybox/bin/modprobe \"\$MODALIAS\"" > rootfs/etc/mdev.conf

    # bash-static components
    cp tmp/bin/bash-static rootfs/bin
    cd rootfs/bin && ln -s bash-static bash; cd ../..

    # cdebootstrap-static components
    cp -r tmp/usr/share/cdebootstrap-static rootfs/usr/share/
    cp tmp/usr/bin/cdebootstrap-static rootfs/usr/bin/

    # coreutils components
    cp tmp/bin/cat rootfs/bin/
    cp tmp/bin/chgrp rootfs/bin/
    cp tmp/bin/chmod rootfs/bin/
    cp tmp/bin/chown rootfs/bin/
    cp tmp/bin/cp rootfs/bin/
    cp tmp/bin/date rootfs/bin/
    cp tmp/bin/dd rootfs/bin/
    cp tmp/bin/df rootfs/bin/
    cp tmp/bin/dir rootfs/bin/
    cp tmp/bin/echo rootfs/bin/
    cp tmp/bin/false rootfs/bin/
    cp tmp/bin/ln rootfs/bin/
    cp tmp/bin/ls rootfs/bin/
    cp tmp/bin/mkdir rootfs/bin/
    cp tmp/bin/mknod rootfs/bin/
    cp tmp/bin/mktemp rootfs/bin/
    cp tmp/bin/mv rootfs/bin/
    cp tmp/bin/pwd rootfs/bin/
    cp tmp/bin/readlink rootfs/bin/
    cp tmp/bin/rm rootfs/bin/
    cp tmp/bin/rmdir rootfs/bin/
    cp tmp/bin/sleep rootfs/bin/
    cp tmp/bin/stty rootfs/bin/
    cp tmp/bin/sync rootfs/bin/
    cp tmp/bin/touch rootfs/bin/
    cp tmp/bin/true rootfs/bin/
    cp tmp/bin/uname rootfs/bin/
    cp tmp/bin/vdir rootfs/bin/

    # diffutils components
    cp tmp/usr/bin/cmp rootfs/usr/bin/

    # dosfstools components
    cp tmp/sbin/fatlabel rootfs/sbin/
    cp tmp/sbin/fsck.fat rootfs/sbin/
    cp tmp/sbin/mkfs.fat rootfs/sbin/
    cd rootfs/sbin
    ln -s fatlabel dosfslabel
    ln -s fsck.fat dosfsck
    ln -s fsck.fat fsck.msdos
    ln -s fsck.fat fsck.vfat
    ln -s mkfs.fat mkdosfs
    ln -s mkfs.fat mkfs.msdos
    ln -s mkfs.fat mkfs.vfat
    cd ../..

    # dpkg components
    cp tmp/etc/alternatives/README rootfs/etc/alternatives/
    cp tmp/etc/cron.daily/dpkg rootfs/etc/cron.daily/
    cp tmp/etc/dpkg/dpkg.cfg rootfs/etc/dpkg/
    cp tmp/etc/logrotate.d/dpkg rootfs/etc/logrotate.d/
    cp tmp/sbin/start-stop-daemon rootfs/sbin/
    cp tmp/usr/bin/dpkg rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-deb rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-divert rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-maintscript-helper rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-query rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-split rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-statoverride rootfs/usr/bin/
    cp tmp/usr/bin/dpkg-trigger rootfs/usr/bin/
    cp tmp/usr/bin/update-alternatives rootfs/usr/bin/
    cp tmp/usr/share/dpkg/abitable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/cputable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/ostable rootfs/usr/share/dpkg/
    cp tmp/usr/share/dpkg/triplettable rootfs/usr/share/dpkg/
    cd rootfs/usr/sbin
    ln -s ../bin/dpkg-divert dpkg-divert
    ln -s ../bin/dpkg-statoverride dpkg-statoverride
    ln -s ../bin/update-alternatives update-alternatives
    cd ../../..
    touch rootfs/var/lib/dpkg/status

    # e2fslibs components
    cp tmp/lib/*/libe2p.so.2.* rootfs/lib/libe2p.so.2
    cp tmp/lib/*/libext2fs.so.2.*  rootfs/lib/libext2fs.so.2

    # e2fsprogs components
    cp tmp/etc/mke2fs.conf rootfs/etc/
    cp tmp/sbin/badblocks rootfs/sbin/
    cp tmp/sbin/debugfs rootfs/sbin/
    cp tmp/sbin/dumpe2fs rootfs/sbin/
    cp tmp/sbin/e2fsck rootfs/sbin/
    cp tmp/sbin/e2image rootfs/sbin/
    cp tmp/sbin/e2undo rootfs/sbin/
    cp tmp/sbin/logsave rootfs/sbin/
    cp tmp/sbin/mke2fs rootfs/sbin/
    cp tmp/sbin/resize2fs rootfs/sbin/
    cp tmp/sbin/tune2fs rootfs/sbin/
    cp tmp/usr/bin/chattr rootfs/usr/bin/
    cp tmp/usr/bin/lsattr rootfs/usr/bin/
    cp tmp/usr/sbin/e2freefrag rootfs/usr/sbin/
    cp tmp/usr/sbin/e4defrag rootfs/usr/sbin/
    cp tmp/usr/sbin/filefrag rootfs/usr/sbin/
    cp tmp/usr/sbin/mklost+found rootfs/usr/sbin/
    cd rootfs/sbin
    ln -s tune2fs e2lablel
    ln -s e2fsck fsck.ext2
    ln -s e2fsck fsck.ext3
    ln -s e2fsck fsck.ext4
    ln -s e2fsck fsck.ext4dev
    ln -s mke2fs mkfs.ext2
    ln -s mke2fs mkfs.ext3
    ln -s mke2fs mkfs.ext4
    ln -s mke2fs mkfs.ext4dev
    cd ../..

    # f2fs-tools components
    cp tmp/sbin/mkfs.f2fs rootfs/sbin/
    cp tmp/lib/*/libf2fs.so.0  rootfs/lib/

    # gpgv components
    cp tmp/usr/bin/gpgv rootfs/usr/bin/

    # ifupdown components
    cp tmp/etc/default/networking rootfs/etc/default/
    cp tmp/etc/init/network-interface-container.conf rootfs/etc/init/
    cp tmp/etc/init/network-interface-security.conf rootfs/etc/init/
    cp tmp/etc/init/network-interface.conf rootfs/etc/init/
    cp tmp/etc/init/networking.conf rootfs/etc/init/
    cp tmp/etc/init.d/networking rootfs/etc/init.d/
    cp tmp/etc/network/if-down.d/upstart rootfs/etc/network/if-down.d/
    cp tmp/etc/network/if-up.d/upstart rootfs/etc/network/if-up.d/
    cp tmp/lib/ifupdown/settle-dad.sh rootfs/lib/ifupdown/
    cp tmp/sbin/ifup rootfs/sbin/
    cd rootfs/sbin
    ln -s ifup ifdown
    ln -s ifup ifquery
    cd ../..

    # iproute2 components
    cp tmp/bin/ip rootfs/bin/
    cp tmp/bin/ss rootfs/bin/
    cp tmp/etc/iproute2/ematch_map rootfs/etc/iproute2/
    cp tmp/etc/iproute2/group rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_dsfield rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_protos rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_realms rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_scopes rootfs/etc/iproute2/
    cp tmp/etc/iproute2/rt_tables rootfs/etc/iproute2/
    cp tmp/sbin/bridge rootfs/sbin/
    cp tmp/sbin/rtacct rootfs/sbin/
    cp tmp/sbin/rtmon rootfs/sbin/
    cp tmp/sbin/tc rootfs/sbin/
    cd rootfs/sbin
    ln -s ../bin/ip ip
    cd ../..
    cp tmp/usr/bin/lnstat rootfs/usr/bin/
    cp tmp/usr/bin/nstat rootfs/usr/bin/
    cp tmp/usr/bin/routef rootfs/usr/bin/
    cp tmp/usr/bin/routel rootfs/usr/bin/
    cd rootfs/usr/bin
    ln -s lnstat ctstat
    ln -s lnstat rtstat
    cd ../../..
    cp tmp/usr/lib/tc/experimental.dist rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/m_xt.so rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/normal.dist rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/pareto.dist rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/paretonormal.dist rootfs/usr/lib/tc
    cp tmp/usr/lib/tc/q_atm.so rootfs/usr/lib/tc
    cd rootfs/usr/lib/tc
    ln -s m_xt.so m_ipt.so
    cd ../../../..
    cp tmp/usr/sbin/arpd rootfs/usr/sbin/

    # lsb-base components
    cp tmp/lib/lsb/init-functions rootfs/lib/lsb/
    cp tmp/lib/lsb/init-functions.d/20-left-info-blocks rootfs/lib/lsb/init-functions.d/

    # netbase components
    cp tmp/etc/protocols rootfs/etc/
    cp tmp/etc/rpc rootfs/etc/
    cp tmp/etc/services rootfs/etc/

    # ntpdate components
    cp tmp/etc/default/ntpdate rootfs/etc/default/
    # don't use /etc/ntp.conf since we don't have it
    sed -i s/NTPDATE_USE_NTP_CONF=yes/NTPDATE_USE_NTP_CONF=no/ rootfs/etc/default/ntpdate
    cp tmp/etc/network/if-up.d/ntpdate rootfs/etc/network/if-up.d/
    cp tmp/usr/sbin/ntpdate rootfs/usr/sbin/
    cp tmp/usr/sbin/ntpdate-debian rootfs/usr/sbin/

    # raspberrypi.org GPG key
    cp packages/raspberrypi.gpg.key rootfs/usr/share/keyrings/

    # raspbian-archive-keyring components
    cp tmp/usr/share/keyrings/raspbian-archive-keyring.gpg rootfs/usr/share/keyrings/

    # rng-tools components
    cp tmp/usr/bin/rngtest rootfs/usr/bin/
    cp tmp/usr/sbin/rngd rootfs/usr/sbin/
    cp tmp/etc/default/rng-tools rootfs/etc/default/
    cp tmp/etc/init.d/rng-tools rootfs/etc/init.d/

    # tar components
    cp tmp/bin/tar rootfs/bin/
    cp tmp/etc/rmt rootfs/etc/
    cp tmp/usr/lib/mime/packages/tar rootfs/usr/lib/mime/packages/
    cp tmp/usr/sbin/rmt-tar rootfs/usr/sbin/
    cp tmp/usr/sbin/tarcat rootfs/usr/sbin/

    # util-linux components
    cp tmp/sbin/blkid rootfs/sbin/
    cp tmp/sbin/blockdev rootfs/sbin/
    cp tmp/sbin/fdisk rootfs/sbin/
    cp tmp/sbin/fsck rootfs/sbin/
    cp tmp/sbin/mkswap rootfs/sbin/
    cp tmp/sbin/swaplabel rootfs/sbin/

    # wpa_supplicant components
    cp tmp/sbin/wpa_supplicant rootfs/sbin/wpa_supplicant
    cp -r tmp/etc/wpa_supplicant rootfs/etc/wpa_supplicant

    # libacl1 components
    cp tmp/lib/*/libacl.so.1.* rootfs/lib/libacl.so.1

    # libatm1 components
    cp tmp/lib/*/libatm.so.1.* rootfs/lib/libatm.so.1

    # libattr1 components
    cp tmp/lib/*/libattr.so.1.* rootfs/lib/libattr.so.1

    # libaudit-common components
    cp tmp/etc/libaudit.conf rootfs/etc/

    # libaudit1 components
    cp tmp/lib/*/libaudit.so.1.* rootfs/lib/libaudit.so.1

    # libblkid1 components
    cp tmp/lib/*/libblkid.so.1.* rootfs/lib/libblkid.so.1

    # libbz2-1.0 components
    cp tmp/lib/*/libbz2.so.1.0.* rootfs/lib/libbz2.so.1.0

    # libc-bin components
    cp tmp/etc/default/nss rootfs/etc/default/
    cp tmp/etc/ld.so.conf.d/libc.conf rootfs/etc/ld.so.conf.d/
    cp tmp/etc/bindresvport.blacklist rootfs/etc/
    cp tmp/etc/gai.conf rootfs/etc/
    cp tmp/etc/ld.so.conf rootfs/etc/
    cp tmp/sbin/ldconfig rootfs/sbin/
    cp tmp/sbin/ldconfig.real rootfs/sbin/
    cp tmp/usr/bin/catchsegv rootfs/usr/bin/
    cp tmp/usr/bin/getconf rootfs/usr/bin/
    cp tmp/usr/bin/getent rootfs/usr/bin/
    cp tmp/usr/bin/iconv rootfs/usr/bin/
    cp tmp/usr/bin/ldd rootfs/usr/bin/
    cp tmp/usr/bin/locale rootfs/usr/bin/
    cp tmp/usr/bin/localedef rootfs/usr/bin/
    cp tmp/usr/bin/pldd rootfs/usr/bin/
    cp tmp/usr/bin/tzselect rootfs/usr/bin/
    cp tmp/usr/bin/zdump rootfs/usr/bin/
    # lib/locale ?
    cp tmp/usr/sbin/iconvconfig rootfs/usr/sbin/
    cp tmp/usr/sbin/zic rootfs/usr/sbin/
    cp tmp/usr/share/libc-bin/nsswitch.conf rootfs/usr/share/libc-bin/

    # libc6 components
    cp tmp/lib/*/ld-*.so rootfs/lib/ld-linux-armhf.so.3
    # some executables require the dynamic linker to be found
    # at this path, so leave a symlink there
    ln -s /lib/ld-linux-armhf.so.3 rootfs/lib/arm-linux-gnueabihf/ld-linux.so.3
    cp tmp/lib/*/libanl-*.so rootfs/lib/libanl.so.1
    cp tmp/lib/*/libBrokenLocale-*.so rootfs/lib/libBrokenLocale.so.1
    cp tmp/lib/*/libc-*.so rootfs/lib/libc.so.6
    cp tmp/lib/*/libcidn-*.so rootfs/lib/libcidn.so.1
    cp tmp/lib/*/libcrypt-*.so rootfs/lib/libcrypt.so.1
    cp tmp/lib/*/libdl-*.so rootfs/lib/libdl.so.2
    cp tmp/lib/*/libm-*.so  rootfs/lib/libm.so.6
    cp tmp/lib/*/libmemusage.so rootfs/lib/
    cp tmp/lib/*/libnsl-*.so rootfs/lib/libnsl.so.1
    cp tmp/lib/*/libnss_compat-*.so rootfs/lib/libnss_compat.so.2
    cp tmp/lib/*/libnss_dns-*.so rootfs/lib/libnss_dns.so.2
    cp tmp/lib/*/libnss_files-*.so rootfs/lib/libnss_files.so.2
    cp tmp/lib/*/libnss_hesiod-*.so rootfs/lib/libnss_hesiod.so.2
    cp tmp/lib/*/libnss_nis-*.so rootfs/lib/libnss_nis.so.2
    cp tmp/lib/*/libpcprofile.so rootfs/lib/
    cp tmp/lib/*/libpthread-*.so rootfs/lib/libpthread.so.0
    cp tmp/lib/*/libresolv-*.so rootfs/lib/libresolv.so.2
    cp tmp/lib/*/librt-*.so rootfs/lib/librt.so.1
    cp tmp/lib/*/libSegFault.so rootfs/lib/
    cp tmp/lib/*/libthread_db-*.so rootfs/lib/libthread_db.so.1
    cp tmp/lib/*/libutil-*.so rootfs/lib/libutil.so.1

    # libcap2 components
    cp tmp/lib/*/libcap.so.2.* rootfs/lib/libcap.so.2

    # libcomerr2 components
    cp tmp/lib/*/libcom_err.so.2.* rootfs/lib/libcom_err.so.2

    # libdb5.3 components
    cp tmp/usr/lib/*/libdb-5.3.so rootfs/usr/lib/libdb5.3.so

    # libdbus-1-3 components
    cp tmp/lib/*/libdbus-1.so.3 rootfs/lib/libdbus-1.so.3
    cp tmp/lib/*/libdl.so.2 rootfs/lib/libdl.so.2

    # libgcc1 components
    cp tmp/lib/*/libgcc_s.so.1 rootfs/lib/
    cp tmp/lib/*/librt.so.1 rootfs/lib/

    # liblzma5 components
    cp tmp/lib/*/liblzma.so.5.* rootfs/lib/liblzma.so.5

    # liblzo2-2 components
    cp tmp/lib/*/liblzo2.so.2 rootfs/lib/

    # libmount1 components
    cp tmp/lib/*/libmount.so.1.* rootfs/lib/libmount.so.1

    # libncurses5 components
    cp tmp/lib/*/libncurses.so.5.* rootfs/lib/libncurses.so.5
    cp tmp/usr/lib/*/libform.so.5.* rootfs/usr/lib/libform.so.5
    cp tmp/usr/lib/*/libmenu.so.5.* rootfs/usr/lib/libmenu.so.5
    cp tmp/usr/lib/*/libpanel.so.5.* rootfs/usr/lib/libpanel.so.5

    # libnl-3-200 components
    cp tmp/lib/*/libnl-3.so.200 rootfs/lib/libnl-3.so.200

    # libnl-genl-3-200 components
    cp tmp/lib/*/libnl-genl-3.so.200 rootfs/lib/libnl-genl-3.so.200

    # libpam0g components
    cp tmp/lib/*/libpam.so.0.* rootfs/lib/libpam.so.0
    cp tmp/lib/*/libpam_misc.so.0.* rootfs/lib/libpam_misc.so.0
    cp tmp/lib/*/libpamc.so.0.* rootfs/lib/libpamc.so.0

    # libpcre3 components
    cp tmp/lib/*/libpcre.so.3.* rootfs/lib/libpcre.so.3
    cp tmp/usr/lib/*/libpcreposix.so.3.* rootfs/usr/lib/libpcreposix.so.3

    # libpcsclite components
    cp tmp/usr/lib/*/libpcsclite.so.1 rootfs/lib/libpcsclite.so.1

    # libselinux1 components
    cp tmp/lib/*/libselinux.so.1 rootfs/lib/

    # libslang2 components
    cp tmp/lib/*/libslang.so.2.* rootfs/lib/libslang.so.2

    # libsmartcols1 components
    cp tmp/lib/*/libsmartcols.so.1.* rootfs/lib/libsmartcols.so.1

    # libssl1.0.0 components
    cp tmp/usr/lib/*/libcrypto.so.1.0.0 rootfs/usr/lib/
    cp tmp/usr/lib/*/libssl.so.1.0.0 rootfs/usr/lib/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/lib4758cca.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libaep.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libatalla.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libcapi.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libchil.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libcswift.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libgmp.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libgost.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libnuron.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libpadlock.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libsureware.so rootfs/usr/lib/openssl-1.0.0/engines/
    cp tmp/usr/lib/*/openssl-1.0.0/engines/libubsec.so rootfs/usr/lib/openssl-1.0.0/engines/

    # libtinfo5 components
    cp tmp/lib/*/libtinfo.so.5.* rootfs/lib/libtinfo.so.5
    cp tmp/usr/lib/*/libtic.so.5.* rootfs/usr/lib/libtinfo.so.5

    # libuuid1 components
    cp tmp/lib/*/libuuid.so.1.* rootfs/lib/libuuid.so.1

    # zlib1g components
    cp tmp/lib/*/libz.so.1  rootfs/lib/

    # Binary firmware for version 3 Model B wireless
    mkdir -p rootfs/lib/firmware/brcm
    cp -r tmp/lib/firmware/brcm/brcmfmac43430-sdio.txt rootfs/lib/firmware/brcm/
    cp -r tmp/lib/firmware/brcm/brcmfmac43430-sdio.bin rootfs/lib/firmware/brcm/

    # vcgencmd
    ## libraspberrypi-bin
    mkdir -p rootfs/opt/vc/bin
    cp tmp/opt/vc/bin/vcgencmd rootfs/opt/vc/bin/
    mkdir -p rootfs/usr/bin
    ln -s /opt/vc/bin/vcgencmd rootfs/usr/bin/vcgencmd
    cp tmp/usr/share/doc/libraspberrypi-bin/LICENCE rootfs/opt/vc/
    ## libraspberrypi0
    mkdir -p rootfs/etc
    cp tmp/etc/ld.so.conf.d/00-vmcs.conf rootfs/etc/ld.so.conf.d/
    mkdir -p rootfs/opt/vc/lib
    cp tmp/opt/vc/lib/libvcos.so rootfs/opt/vc/lib/
    cp tmp/opt/vc/lib/libvchiq_arm.so rootfs/opt/vc/lib/

    # xxd
    mkdir -p rootfs/usr/bin
    cp tmp/usr/bin/xxd rootfs/usr/bin/

    INITRAMFS="../installer.cpio.gz"
    (cd rootfs && find . | cpio -H newc -ov | gzip --best > $INITRAMFS)

    rm -rf rootfs
}

if [ ! -d packages ]; then
    . ./update.sh
fi

rm -rf tmp
mkdir tmp

# extract debs
for i in packages/*.deb; do
    cd tmp && ar x "../${i}" && tar -xf data.tar.*; rm data.tar.*; cd ..
done

# get kernel versions
get_kernels

# initialize bootfs
rm -rf bootfs
mkdir bootfs

# raspberrypi-bootloader components and kernel
cp -r tmp/boot/* bootfs/

if [ ! -f bootfs/config.txt ] ; then
    touch bootfs/config.txt
fi

create_cpio
cp installer.cpio.gz bootfs/

{
    echo "[all]"
    echo "initramfs installer.cpio.gz"
    echo "[pi3]"
    echo "enable_uart=1"
    echo ""
    echo "# Only for RPi model 3: The following line enables the ability to boot from USB."
    echo "# Notice: This flag will be written to OTP and is permanent."
    echo "#program_usb_boot_mode=1"
} >> bootfs/config.txt

# clean up
rm -rf tmp
rm -f installer.cpio.gz

echo "dwc_otg.lpm_enable=0 consoleblank=0 console=serial0,115200 console=tty1 elevator=deadline rootwait" > bootfs/cmdline.txt

if [ -f installer-config.txt ]; then
    cp installer-config.txt bootfs/
fi

if [ -f post-install.txt ]; then
    cp post-install.txt bootfs/
fi

if [ -d config ] ; then
    mkdir bootfs/config
    cp -r config/* bootfs/config
    mkdir bootfs/config/boot
    cp files/config.txt bootfs/config/boot
fi

version_tag="$(git describe --exact-match --tags HEAD 2> /dev/null || true)"
version_commit="$(git rev-parse --short "@{0}" 2> /dev/null || true)"
if [ -n "${version_tag}" ]; then
    ZIPFILE="raspberrypi-ua-netinst-${version_tag}.zip"
elif [ -n "${version_commit}" ]; then
    ZIPFILE="raspberrypi-ua-netinst-git-${version_commit}.zip"
else
    ZIPFILE="raspberrypi-ua-netinst-$(date +%Y%m%d).zip"
fi
rm -f "${ZIPFILE}"

cd bootfs && zip -r -9 "../${ZIPFILE}" ./*; cd ..
