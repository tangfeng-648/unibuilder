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

declare -A KYLIN_CONFIGS

function set_value() {
    eval "$1"='$2'
    eval "KYLIN_CONFIGS[${1}]"='$2'
}

function get_value() {
    echo "${KYLIN_CONFIGS[${1}]}"
}

# Write all value to .config
# function set_value exports all variables globally by default
# So, following variables are set:
# DISTRO ROOTFSTYPE PLATFORM SUITE CHIP ARCH
function export_config() {
    cat > ${CURRENT_DIR}/.config << EOF
#
# Automatically generated file; DO NOT EDIT.
#
EOF
    for _KEY in "${!KYLIN_CONFIGS[@]}"; do
        echo "$_KEY: ${KYLIN_CONFIGS[$_KEY]}" >> ${CURRENT_DIR}/.config
    done
}

function import_config() {
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        set_value "${line%:*}" "${line#* }"
    done < "${CURRENT_DIR}/.config"
}

function check_tool() {
    local _tools=("dialog" "whiptail" "lxdialog")

    for t in "${_tools[@]}"; do
        check_package ${t} && DIALOG=${t} && return 0
        [[ "$?" == "100" ]] && warning_log "Could not find package ${pkg_name}"
    done
}

function check_config() {
    local options=()
    declare -g CHECKCONFIG_RESULT=""

    check_tool
    check_package coreutils
    check_package gettext

    [ ! -f ${CURRENT_DIR}/.config ] && return 0
    info_log "Config file already exists"

    options+=("Show" "$(gettext 'Show and Use current configuration file')")
    options+=("Generate" "$(gettext 'Create a new configuration file')")

    menu "$(gettext 'Choose an option')" "$BACKTITLE" "$(gettext 'Detected an old config file')" "${options[@]}"
    CHECKCONFIG_RESULT=${MENU_RESULT}

    [[ ${CHECKCONFIG_RESULT} == "Show" ]] && textbox ${CURRENT_DIR}/.config && import_config
    return 0
}

function select_distro() {
    local options=()
    local distro=""

    for distro_dir in "config/distro/"*; do
        distro="$(basename "${distro_dir}")"
        options+=("${distro}" "$(gettext ${distro^}) $(gettext 'desktop environment')")
    done

    menu "$(gettext 'Choose an option')" "$BACKTITLE" "$(gettext 'Select the distro')" "${options[@]}"
    distro=${MENU_RESULT}
    set_value "DISTRO" "${MENU_RESULT}"
    options=()

    for suite_dir in "config/distro/${distro}/"*; do
        suite=$(basename "${suite_dir}")
        [[ ${suite} == "common" ]] && continue
        options+=("${suite}" "$(gettext ${distro^}) $(gettext 'APT Source'): ${suite}")
    done
    menu "$(gettext 'Choose an option')" "$BACKTITLE" "$(gettext 'Select the distro suite')" "${options[@]}"
    set_value "SUITE" "${MENU_RESULT}"
    options=()

    [ ! -d config/distro/${distro}/common ] && return
    [ ! -d config/distro/${distro}/common/apps ] && return
    for app_dir in "config/distro/${distro}/common/apps/"*; do
        app="$(basename "${app_dir}")"
        message="$(gettext $(basename "${app_dir}"))"
        # message="$(head -n1 ${app_dir}/packages), etc"
        options+=("${app}" "${message}" off)
    done
    checklist "$(gettext 'Choose desktop softwares to add')" "$BACKTITLE" "$(gettext 'Press Space to select third-party software')" "${options[@]}"
    [ ! -z "$CHECKLIST_RESULT" ] && set_value "THIRD_APPGROUPS" "${CHECKLIST_RESULT}"

    return 0
}

function select_platform() {
    local options=()
    local platform=""

    [ -f "${CURRENT_DIR}/config/distro/${DISTRO}/${SUITE}/platform_support" ] && platform=$(cat "${CURRENT_DIR}/config/distro/${DISTRO}/${SUITE}/platform_support")
    if [ -z ${platform} ]; then
        for platform_dir in "config/platform/"*; do
            [[ "$platform_dir" == "config/platform/*" ]] && continue
            platform="$(basename "${platform_dir}")"
            options+=("${platform}" "$(gettext ${platform^}) $(gettext 'Platform')")
        done
        [ -z ${platform} ] && return 0
        menu "$(gettext 'Choose an option')" "$BACKTITLE" "$(gettext 'Select chip platform')" "${options[@]}"
        platform=${MENU_RESULT}
    fi
    set_value "PLATFORM" "${platform}"

    options=()
    for chip_dir in "config/platform/${platform}/"*; do
        chip=$(basename "${chip_dir}")
        options+=("${chip}" "${chip^^} $(gettext 'Chip')")
    done
    menu "$(gettext 'Choose an option')" "$BACKTITLE" "$(gettext 'Select chip model')" "${options[@]}"
    set_value "CHIP" "${MENU_RESULT}"

    arch=$(cat "config/platform/${platform}/${chip}/dpkg-arch")
    [ -z $arch ] && arch="arm64"
    set_value "ARCH" ${arch}

    options=()

    return 0
}

function select_board() {
    local options=()
    local board=""

    for board_dir in "config/board/${CHIP}/"*; do
        [[ "$board_dir" == "config/board/${CHIP}/*" ]] && continue
        board="$(basename "${board_dir}")"
        options+=("${board}" "${board^^} $(gettext 'Board Support Binary')")
    done
    [ -z ${board} ] && return 0

    menu "$(gettext 'Choose a board')" "$BACKTITLE" "$(gettext 'Select your board')" "${options[@]}"
    board=${MENU_RESULT}
    set_value "BOARD" "${MENU_RESULT}"
    options=()

    return 0
}

function select_rootfstype() {
    local options=()

    options+=("squashfs" "$(gettext 'The rootfs format is') Squashfs(default)")
    options+=("ext" "$(gettext 'The rootfs format is') Ext")
    menu "$(gettext 'Choose rootfs type')" "$BACKTITLE" "$(gettext 'Select the target image type')" "${options[@]}"
    set_value "ROOTFSTYPE" "${MENU_RESULT}"

    options=()
}

function user_confrim_rm() {
    local options=()
    local to_be_deleted=$1
    declare -g CONFRIM_RM_RESULT=""

    options+=("no" "$(gettext 'Press NO to reuse'): $1")
    options+=("yes" "$(gettext 'Press YES to delete'): $1")

    menu "$(gettext 'Choose an option')" "$BACKTITLE" "$(gettext 'Found a duplicate version')" "${options[@]}"
    CONFRIM_RM_RESULT=${MENU_RESULT}

    options=()
}

function review_config () {
    local _suite=$SUITE
    local _distro=$DISTRO
    local _chip=$CHIP
    local _is_verified="no"
    local options=()

    [[ "${_suite}" =~ "020" ]] && [[ "${_chip}" =~ "ft2000" ]] && _is_verified="yes"
    [[ "${_suite}" =~ "${_chip}" ]] && _is_verified="yes"
    [[ "${_is_verified}" == "no" ]] && msgbox "$(gettext ${_distro^}) ${_suite} $(gettext 'may not fully support') ${_chip} $(gettext 'Platform')" && return 1

    return 0
}

function interactive_os_config(){
    check_config
    [[ ${CHECKCONFIG_RESULT} == "Show" ]] && return 0

    select_distro
    select_platform
    [[ ${PLATFORM} == "rockchip" ]] && select_rootfstype
    select_board

    review_config
    export_config
    return 0
}

