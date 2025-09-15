#!/bin/bash
#
# Copyright (C) 2025, KylinSoft Co., Ltd.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Authors: tangfeng <tangfeng@kylinos.cn>

function create_rootfs() {
    create_base_chroot
    create_rootfs_for_distro
    install_third_party_packages
    make_binary
    return 0
}

function create_base_chroot() {
    set_workdir
    [ -d ${ROOTFS_DIR} ] && [ ! -d ${ROOTFS_DIR}/debootstrap ] && user_confrim_rm ${ROOTFS_DIR}
    [[ $CONFRIM_RM_RESULT == "no" ]] && return 0
    create_base_chroot_via_debootstrap
    return 0
}

function set_workdir() {
    TIMESTAMP=$(date "+%Y%m%d")
    OSNAME="Kylin-Desktop-V10"
    [ ! -z ${PROJECT} ] && PROJECT="${PROJECT}-"
    [ ! -z ${BUILD} ] && BUILD="${BUILD}-"
    CHIP=${CHIP^^}
    OS_VERSION="${OSNAME}-${CHIP:-unknown}-${PROJECT}${BUILD}${TIMESTAMP}-${ARCH}-${VERSION:-rc1}"
    [ ! -d out ] && mkdir out
    ROOTFS_DIR="${CURRENT_DIR}/out/${OS_VERSION}"
    umount_target "${ROOTFS_DIR}"
}

function chroot_cmd(){
    [ -z ${ROOTFS_DIR} ] && return 0
    sudo chroot ${ROOTFS_DIR}/ /bin/bash -c "$1"
}

function create_base_chroot_via_debootstrap() {
    local _mirror="http://archive.kylinos.cn/kylin/KYLIN-ALL"
    local _script="gutsy"
    check_mount_proc /

    info_log "Creating a new chroot for ${DISTRO}"
    [ -z ${ROOTFS_DIR} ] && return 0
    if [ -d "${ROOTFS_DIR}" ]; then
        umount_target "${ROOTFS_DIR}"
	[ -f /usr/bin/chattr ] && [ -f ${ROOTFS_DIR}/etc/resolv.conf ] && chattr -i ${ROOTFS_DIR}/etc/resolv.conf || true
        sudo rm -rf ${ROOTFS_DIR}
    fi

    check_package debootstrap
    check_package mtools
    check_package genisoimage
    check_package squashfs-tools
    check_package liblzo2-2
    check_package lsb-release

    if [[ "$(dpkg --print-architecture)" != "${ARCH}" ]]; then
        [[ "${ARCH}" == "loongarch64" ]] && fault_log_exit "loongarch64 is not supported: qemu-user-static unavailable."
        check_package binfmt-support
        check_package qemu-user-static
        if [[ "$(systemd-detect-virt)" == "wsl" ]] ;then
            [ -f /usr/sbin/update-binfmts ] && /usr/sbin/update-binfmts --enable
            [ -f /usr/bin/qemu-aarch64-static ] && mkdir -p ${ROOTFS_DIR}/usr/bin && cp /usr/bin/qemu-aarch64-static ${ROOTFS_DIR}/usr/bin/
        fi
    fi

    if [[ ${DISTRO} == "kylin" ]] ; then # The workaround only works on kylin os
        # hsdimm-lite leads to debootstrap fail. and do this workaround to fix.
        [[ "${SUITE}" == "10.1-rk3588b03" ]] && mkdir -p ${ROOTFS_DIR}/usr/bin && touch ${ROOTFS_DIR}/usr/bin/systemctl && chmod +x ${ROOTFS_DIR}/usr/bin/systemctl

        # loongarch64 2k2000/2k1000 workaround
        [[ "${SUITE}" == "10.1-loongson-2k2000" ]] || [[ "${SUITE}" == "10.1-loongson-2k1000" ]] && SUITE="10.1-la64"

        # forcing merge user
        [ -f /usr/share/debootstrap/functions ] && sudo cp /usr/share/debootstrap/functions /usr/share/debootstrap/functions_orig
        sudo sed -i '/^setup_merged_usr/a\\tMERGED_USR=yes' /usr/share/debootstrap/functions
    fi

    [[ "$(lsb_release -cs)" == "bionic" ]] && _script=/usr/share/debootstrap/scripts/${_script}
    sudo debootstrap --no-check-gpg --variant=minbase --arch=${ARCH} --include='apt,wget,gnupg' --components=main,universe ${SUITE} ${ROOTFS_DIR} ${_mirror} ${_script}
    [[ $? != 0 ]] && fault_log_exit "BUG: debootstrap failed"

    [ -f /usr/share/debootstrap/functions_orig ] && sudo mv /usr/share/debootstrap/functions_orig /usr/share/debootstrap/functions

    # loongarch64 2k2000/2k1000 workaround
    [[ ${SUITE} == "10.1-la64" ]] && SUITE=$(get_value "SUITE")
    return 0
}

function create_rootfs_for_distro() {
    local _ret=

    info_log "Creating a new rootfs for ${DISTRO}"
    [ -z ${ROOTFS_DIR} ] && return 0
    [ -d ${ROOTFS_DIR}/config ] && sudo rm -rf ${ROOTFS_DIR}/config
    sudo mkdir ${ROOTFS_DIR}/config
    sudo cp -rf ${CURRENT_DIR}/config/distro/${DISTRO}/${SUITE}/* ${ROOTFS_DIR}/config/

    check_mount_dev_run ${ROOTFS_DIR}
    check_mount_proc ${ROOTFS_DIR}

    # TODO: I don't want to be caught by the ERR trap
    export SUITE=${SUITE}
    sudo -E chroot ${ROOTFS_DIR} bash -euo pipefail /config/main.sh
    _ret=$?

    umount_target ${ROOTFS_DIR}

    [ -z ${DEBUG} ] && sudo rm -rf ${ROOTFS_DIR}/config

    # trap SIGINT/SIGQUIT/SIGTERM/SIGKILL
    [[ "${_ret}" == "130" ]] || [[ "${_ret}" == "131" ]] || [[ "${_ret}" == "137" ]] || [[ "${_ret}" == "143" ]] && fault_log_exit "Received signal and exited"

    # error exit
    [[ "${_ret}" == "100" ]] && fault_log_exit "Received error and exited"

    # remove immutable attribute
    _ret=$(chroot_cmd "[ -f /etc/resolv.conf ] && lsattr /etc/resolv.conf | cut -c -20 | grep -q i && echo 0 || echo 1")
    [[ "${_ret}" == "0" ]] && chroot_cmd "chattr -i /etc/resolv.conf"
    return 0
}

function install_third_party_packages() {
    [ -z "${THIRD_APPGROUPS}" ] && return 0
    info_log "Preparing to install third-party package"
    local _distro=${DISTRO}
    local _src=${CURRENT_DIR}
    local _apt_flag="--no-install-recommends --no-install-suggests --yes -o Acquire::Retries=2 -o APT::Get::AllowUnauthenticated=true -o Acquire::AllowInsecureRepositories=1"
    local _pkglist_file=

    chroot_cmd "rm -f /etc/resolv.conf"
    chroot_cmd "echo 'nameserver ${NAMESERVER:-114.114.114.114}' > /etc/resolv.conf"
    info_log "Installing third-party packages for ${DISTRO}"
    for _apps in ${THIRD_APPGROUPS}; do
        _pkglist_file="${_src}/config/distro/${_distro}/common/apps/${_apps}/packages"
        [ -f ${_pkglist_file} ] && chroot_cmd "apt-get install -fy ${_apt_flag} $(grep -v "^#" ${_pkglist_file} | xargs)"
    done
    return 0
}

function trim_chroot() {
    chroot_cmd "rm -rf /usr/share/doc/*"
    chroot_cmd "rm -rf /usr/share/man/*"
    chroot_cmd "rm -rf /usr/share/help/*"
    chroot_cmd "rm -rf /usr/share/info/*"
    chroot_cmd "apt clean"
    chroot_cmd "rm -rf /var/lib/apt/lists/*"
}

function make_iso() {
    info_log "Preparing make iso for ${CHIP}"
    local _iso="${ROOTFS_DIR}-iso"
    local _iso_binary="${CURRENT_DIR}/out/binary-${PLATFORM}"
    local _config=${CURRENT_DIR}/config
    local _rootfs=${ROOTFS_DIR}

    [ ! -d ${_iso_binary} ] && return 0

    [ ! -d ${_iso}/casper ] && sudo mkdir -p ${_iso}/casper
    [ ! -d ${_iso}/boot ] && sudo mkdir -p ${_iso}/boot

    sudo cp -raf ${_iso_binary}/* ${_iso}/

    # copy vmlinuz and initrd.lz for uefi boot
    local _bootmode=""
    if [ -f ${_rootfs}/boot/initrd.img ] && [ -f ${_rootfs}/boot/vmlinuz ]; then
        sudo cp ${_rootfs}/boot/vmlinuz ${_rootfs}-iso/casper/
        sudo cp ${_rootfs}/boot/initrd.img ${_rootfs}-iso/casper/initrd.lz
        _bootmode="uefi"
    fi

    # copy uImage and uInitrd for uboot boot
    if [ -f ${_rootfs}/boot/uImage ] && [ -f ${_rootfs}/boot/uInitrd ]; then
        sudo cp ${_rootfs}/boot/uImage ${_rootfs}-iso/boot/
        sudo cp ${_rootfs}/boot/uInitrd ${_rootfs}-iso/boot/
        _bootmode="uboot"
    fi
    [ -z "${_bootmode}" ] && fault_log_exit "Kernel and Initrd not found"

    # copy kylin-build
    sudo cp ${_rootfs}/etc/kylin-build ${_iso}/

    # physical link filesystem.squashfs
    [ -f ${_rootfs}.squashfs ] && sudo ln -Pf ${_rootfs}.squashfs ${_iso}/casper/filesystem.squashfs

    # copy squashfs.size and deblist
    [ -f ${_rootfs}.squashfs.size ] && sudo cp ${_rootfs}.squashfs.size ${_iso}/casper/filesystem.size
    [ -f ${_rootfs}.deblist ] && sudo cp ${_rootfs}.deblist ${_iso}/casper/filesystem.packages

    # md5sum
    pushd ${_iso}
    [ -f ./md5sum.txt ] && sudo rm -f ./md5sum.txt
    for f in "$(find . -type f)"; do
        sudo md5sum ${f} >> ./md5sum.txt
    done
    popd

    # make iso
    sudo mkisofs -input-charset utf-8 -J -r -V "Kylin-Desktop-V10" -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -o ${_rootfs}.iso ${_iso}/

    sudo rm -rf ${_iso}/

    info_log "Make iso successfully. file: ${_rootfs}.iso"
}

function make_update() {
    local _rootfs=${ROOTFS_DIR}
    local _kypack="${CURRENT_DIR}/tool/kypacker/"
    info_log "Preparing make update image for ${CHIP}"

    [ ! -f /usr/bin/python3 ] && fault_log "Your system not support python3" && return 0
    (( $(echo "$(python3 --version | awk '{print $2}' | cut -d. -f2,3) < 7" | bc -l) )) && warning_log "Python version is too low, Skiping make update" && return 0
    [ ! -f ${_kypack}/update.img ] && rm -f ${_kypack}/update.img

    # check files
    local _rk_binary="${CURRENT_DIR}/out/binary-${PLATFORM}"
    [ ! -f ${_rk_binary}/package-file ] && fault_log "file package-file not found. exiting" && return 0

    info_log "Building update.img"
    local _update="${_rootfs}-update"
    [ ! -d ${_update}/Image ] && sudo mkdir -p ${_update}/Image
    sudo ln -sf ${_rootfs}.squashfs ${_update}/Image/rootfs.img

    sudo cp ${_rk_binary}/package-file ${_update}/package-file
    while read _tag _file; do
        [[ -z "$_tag" || "$_tag" =~ ^[[:space:]]*# ]] && continue
        [[ ${_tag} == "rootfs" ]] && continue
        [ ! -f ${_rk_binary}/${_file} ] && fault_log "file ${_rk_binary}/${_file} not found. exiting" && return 0
        sudo cp ${_rk_binary}/${_file} ${_update}/${_file}
        [ ! -f ${_update}/${_file} ] && fault_log "file ${_update}/${_file} not found. exiting" && return 0
    done < <(awk '{print $1, $2}' ${_update}/package-file)

    [ ! -f ${_kypack}/librkcrc32.so ] && make -C ${_kypack}
    pushd ${_kypack}/
    sudo python3 kyPacker.py afptool pack ${_update}/ ${_update}/Image/firmware.img
    sudo python3 kyPacker.py imgmker pack ${CHIP} ${_update}/Image/MiniLoaderAll.bin ${_update}/Image/firmware.img -os_type androidos
    popd

    [ ! -f ${_kypack}/update.img ] && fault_log "can not find update.img" && return 0
    sudo mv ${_kypack}/update.img ${_update}.img && sudo rm -rf ${_update}

    info_log "Make update.img successfully. file: ${_update}.img"

    return 0
}

function get_binary() {
    local _use_board_binary="no"
    local _deb_name="${CHIP,,}-binary"
    local _binary_dir="${CURRENT_DIR}/config/platform/${PLATFORM}/${CHIP,,}/"
    local _ret=0

    [ -d ${CURRENT_DIR}/out/binary-${PLATFORM} ] && sudo rm -rf ${CURRENT_DIR}/out/binary-${PLATFORM}
    [ ! -z ${BOARD} ] && _use_board_binary="yes"

    # Firstly: get binary from apt source
    [[ "${_use_board_binary}" == "yes" ]] && _deb_name="${BOARD}-binary"
    sudo chroot ${ROOTFS_DIR} bash -c "apt update"
    sudo chroot ${ROOTFS_DIR} bash -c "apt install ${_deb_name}"
    _ret="$?" && [[ "${_ret}" == "0" ]] && [ -d ${ROOTFS_DIR}/binary ] && sudo mv ${ROOTFS_DIR}/binary ${CURRENT_DIR}/out/binary-${PLATFORM} && return 0

    # Secondly: get binary from local deb
    [[ "${_use_board_binary}" == "yes" ]] && _binary_dir="${CURRENT_DIR}/config/board/${CHIP,,}/${BOARD}/"
    sudo cp ${_binary_dir}/${_deb_name}_all.deb ${ROOTFS_DIR}/ && sudo chroot ${ROOTFS_DIR} bash -c "dpkg -i /${_deb_name}_all.deb"
    _ret="$?" && [[ "${_ret}" == "0" ]] && [ -d ${ROOTFS_DIR}/binary ] && sudo mv ${ROOTFS_DIR}/binary ${CURRENT_DIR}/out/binary-${PLATFORM} && sudo rm ${ROOTFS_DIR}/${_deb_name}_all.deb && return 0

    # Finally: get binary from directory
    sudo cp -rf ${_binary_dir}/binary ${CURRENT_DIR}/out/binary-${PLATFORM}

    return 0
}

function make_binary() {
    # get binary
    # allow error to occur
    set +eE
    get_binary
    set -eE

    # record package list
    sudo chroot ${ROOTFS_DIR} bash -c "dpkg -l | grep ^i" > ${ROOTFS_DIR}.deblist

    # trim chroot
    trim_chroot

    umount_target ${ROOTFS_DIR}

    [ -z "${ROOTFSTYPE}" ] && ROOTFSTYPE="squashfs"
    info_log "Begin building root filesystem image ${ROOTFSTYPE}"
    make_binary_squashfs
    [[ "${ROOTFSTYPE}" == "ext" ]] && make_binary_ext4

    # make iso or update
    if [[ "${CHIP}" =~ "RK" ]]; then
        make_update
    else
        make_iso
    fi

    # remove out/binary
    sudo rm -rf out/binary-${PLATFORM}
    return 0
}

function make_binary_squashfs() {
    info_log "Preparing squashfs image"
    [ -f ${ROOTFS_DIR}.squashfs ] && sudo rm -rf ${ROOTFS_DIR}.squashfs
    sudo mksquashfs ${ROOTFS_DIR} ${ROOTFS_DIR}.squashfs # -no-progress -quiet -comp xz 
    printf $(sudo du -sx --block-size=1 ${ROOTFS_DIR} | cut -f1) > ${ROOTFS_DIR}.squashfs.size
    return 0
}

function make_binary_ext4() {
    info_log "Preparing ext image"
    ! mountpoint /dev -q && fault_log "/dev is not a mount point on the host, skip mkfs.ext4." && return 0

    local _size=$(sudo du -sm ${ROOTFS_DIR} | awk '{print $1}')
    local _need_size=$((${_size} + 1024))
    local _image_file="${ROOTFS_DIR}.ext4"
    local _tempdir="$(mktemp -d)"
    local _availspace=$(df ${ROOTFS_DIR} -m --output=avail | awk 'NR==2 {print $1}')
    if [[ ${_availspace} -lt ${_need_size} ]]; then
        fault_log "Not enough space on ${ROOTFS_DIR}"
        return 0
    fi

    [ -f ${_image_file} ] && rm -f ${_image_file}
    sudo dd if=/dev/zero of=${_image_file} bs=1M count=${_need_size} status=progress
    yes | mkfs.ext4 -Fq -L ROOT ${_image_file}
    sudo mount -o loop ${_image_file} ${_tempdir}
    sudo cp -rf -a ${ROOTFS_DIR}/* ${_tempdir}
    sync
    sudo umount ${_tempdir}
    e2fsck -fp  ${_image_file}
    resize2fs -M ${_image_file}

    sudo rmdir ${_tempdir}
}
