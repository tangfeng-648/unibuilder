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

MENU_VERSION=1.0
declare -g -r BACKTITLE="$(gettext 'Kylin OS Building Script')v${MENU_VERSION}. $(gettext 'Author'): tangfeng"
declare -g TTY_X=$(($(stty size | awk '{print $2}') - 6))
declare -g TTY_Y=$(($(stty size | awk '{print $1}') - 6))

function ask_by_whiptail() {
    declare -g ASK_RESULT=""
    declare -g ASK_EXIT=0

    [[ -t 0 && -t 1 && -t 2 ]] || fault_log_exit "not a terminal. can't use whiptail"

    exec 3>&1
    ASK_RESULT=$(whiptail "$@" 2>&1 1>&3)
    ASK_EXIT=$?
    exec 3>&-

    clear

    [[ ${ASK_EXIT} != 0 ]] && fault_log_exit "User cancelled."

    return 0
}

function ask_by_dialog() {
    declare -g ASK_RESULT=""
    declare -g ASK_EXIT=0

    [[ -t 0 && -t 1 && -t 2 ]] || fault_log_exit "not a terminal. can't use dialog."

    exec 3>&1
    ASK_RESULT=$(dialog "$@" 2>&1 1>&3)
    ASK_EXIT=$?
    exec 3>&-

    clear

    [[ ${ASK_EXIT} != 0 ]] && fault_log_exit "User cancelled."

    return 0
}

function ask() {
    [ -z $DIALOG ] && DIALOG="dialog"

    set +eE
    [[ $DIALOG == "dialog" ]] && ask_by_dialog "${@}"
    [[ $DIALOG == "whiptail" ]] && ask_by_whiptail "${@}"

    # TODO
    [[ $DIALOG == "lxdialog" ]] && true

    set -eE
    return 0
}

# $1: title
# $2: backtitle
# $3: menu
# $4: options
function menu() {
    declare -g MENU_RESULT=""
    title=$1
    backtitle=$2
    menu=$3
    ask --title "$title" --backtitle "${backtitle}" --menu "$menu" $TTY_Y $TTY_X $((TTY_Y - 8)) "${@:4}"
    MENU_RESULT=${ASK_RESULT}
    return 0
}

# $1: title
# $2: backtitle
# $3: checklist
# $4: options
function checklist() {
    declare -g CHECKLIST_RESULT=""
    title=$1
    backtitle=$2
    menu=$3
    ask --title "${title}" --backtitle "${backtitle}" --checklist "${menu}" $TTY_Y $TTY_X $((TTY_Y - 8)) "${@:4}"
    CHECKLIST_RESULT=${ASK_RESULT}
    return 0
}

# $1: file
function textbox() {
    file=$1
    ask --textbox "${file}" $TTY_Y $TTY_X
    return 0
}

# $1: message
function msgbox() {
    msg=$1
    ask --msgbox "${msg}" 10 80
}
