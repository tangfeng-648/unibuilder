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

function def_color() {
    BLK='\033[0;30m'
    RED='\033[0;31m'
    GRN='\033[0;32m'
    BLU='\033[0;34m'
    CYA='\033[0;36m'
    WHI='\033[0;37m'
    YEL='\033[0;33m'
    PUR='\033[0;35m'
    NC='\033[0m'
}

function logging_init() {
    CODENAME="\033[1;44m🦄\033[0m"

    def_color

    if [ -z ${DEBUG} ]
    then
        LOG_FILE="/dev/null"
    else
        SOURCE=$(basename ${BASH_SOURCE[-1]})
        LOG_FILE="${SOURCE%.*}.log"
        [ -f ${LOG_FILE} ] && rm -f ${LOG_FILE}
    fi
    return 0
}

function info_log() {
    echo -e "[${CODENAME}] $(basename ${BASH_SOURCE[1]}) [ ${GRN}$1${NC} ]" | tee -a ${LOG_FILE}
}

function warning_log() {
    echo -e "[${CODENAME}] $(basename ${BASH_SOURCE[1]}) [ ${CYA}$1${NC} ]" | tee -a ${LOG_FILE}
}

function fault_log() {
    echo -e "[${CODENAME}] $(basename ${BASH_SOURCE[1]}) [ ${RED}$1${NC} ]" | tee -a ${LOG_FILE}
}

function fault_log_exit() {
    echo -e "[${CODENAME}] $(basename ${BASH_SOURCE[1]}) [ ${RED}$1${NC} ]" | tee -a ${LOG_FILE}
    exit 42
}

logging_init
