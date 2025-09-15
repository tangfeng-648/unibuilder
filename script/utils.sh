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

function check_package() {
    pkg_name="$1"
    if [ -n "${pkg_name}" ]; then
        if ! dpkg -l | grep "^ii  ${pkg_name}"; then
            sudo apt-get install -y ${pkg_name}
        fi
    fi
}

function check_mount_proc() {
    local _target=$1
    ! mountpoint -q ${_target}/proc && sudo mount -t proc proc ${_target}/proc
    return 0
}

function check_mount_dev_run() {
    local _target=$1
    mountpoint -q /dev || mountpoint -q /run && mount_host_to_target ${_target}
    return 0
}

function mount_host_to_target() {
    sudo mount --bind /dev ${1}/dev
    sudo mount --bind /run ${1}/run
    sudo mount -t devpts devpts ${1}/dev/pts
    sudo mount -t proc proc ${1}/proc
    sudo mount -t sysfs sysfs ${1}/sys
}

function umount_target() {
    sudo umount -l ${1}/* >/dev/null 2>&1 || true
    sudo umount ${1} >/dev/null 2>&1 || true
}
