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

set -eE

declare -g CURRENT_DIR="$(dirname $(readlink -f $0))"
declare -g ROOTFS_DIR=
declare -g NAMESERVER=114.114.114.114

LOCKFILE="${BASH_SOURCE[-1]%.*}.lock"

if [ ! -d ${CURRENT_DIR}/.git ]; then
    # the main script in the script directory, so using dirname twice
    declare -g CURRENT_DIR="$(dirname ${CURRENT_DIR})"
fi

export TEXTDOMAINDIR=${CURRENT_DIR}/locale
export TEXTDOMAIN=dict

exit_function() {
    [ ! -z ${LOCKFILE} ] && sudo rm -f ${LOCKFILE}
    unset LOCKFILE
    [ ! -z ${ROOTFS_DIR} ] && umount_target "${ROOTFS_DIR}"
    return 0
}

trap '[[ "${BASH_LINENO[0]}" != "0" ]] && fault_log "Build failed at ${BASH_SOURCE[1]}:${BASH_LINENO[0]}"' ERR
trap "exit_function" 0

source ${CURRENT_DIR}/script/log.sh
source ${CURRENT_DIR}/script/dialog.sh
source ${CURRENT_DIR}/script/interactive.sh
source ${CURRENT_DIR}/script/utils.sh
source ${CURRENT_DIR}/script/create-rootfs.sh

check_single_instance() {
    if [ -f ${LOCKFILE} ]; then
        trap - ERR
        echo "Someone is running this program. Please check lockfile:[${LOCKFILE}]"
        LOCKFILE=
    else
        sudo touch ${LOCKFILE}
    fi

    return 0
}

prepare_host() {
    NAMESERVER=172.25.20.2

    grep -q "[[:space:]]" <<< "${CURRENT_DIR}" && {
        fault_log_exit "\"${CURRENT_DIR}\" contains whitespace. Not supported. Aborting." >&2
    }

    if [ $(id -u) != 0 ]; then
        sudo tee /etc/sudoers.d/$USER <<EOF
$USER ALL=(ALL:ALL) NOPASSWD: ALL
EOF
    fi

    [ ! -d ${CURRENT_DIR}/out ] && mkdir ${CURRENT_DIR}/out
}


finish_build() {
    unset CURRENT_DIR
    unset TIMESTAMP
    unset OSNAME
    unset NAMESERVER
    unset TEXTDOMAINDIR
    unset TEXTDOMAIN
    unset ROOTFS_DIR
    unset TTY_X
    unset TTY_Y
    unset CODENAME

    return 0
}

main () {
    # check single instance
    check_single_instance

    # start interactive config
    interactive_os_config

    # setting host
    prepare_host

    # start build os
    create_rootfs | tee ${CURRENT_DIR}/out/debug-$(date "+%Y%m%d%H").log

    info_log "The ${DISTRO} distribution build has been completed!!!"

    # clean environment variables
    finish_build
}

time (
    main
)

exit 0
