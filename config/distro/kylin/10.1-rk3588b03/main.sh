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

set -e

CURRENT_DIR=$(dirname $(readlink -f $0))

# Step 1: Prepare package sources for installing debs 
function set_deb_sources() {
    # set customed dns
    NAMESERVER="114.114.114.114"
    rm -f /etc/resolv.conf && echo "nameserver ${NAMESERVER}" > /etc/resolv.conf && chattr +i /etc/resolv.conf

    # add public source list
    cat > /etc/apt/sources.list <<EOF
deb [trusted=yes] http://archive.kylinos.cn/kylin/KYLIN-ALL ${SUITE} main restricted universe multiverse
EOF

    # wk for dpkg-deb
    apt-get update
    set +e
    apt-get install -fy dpkg-dev
    set -e

    apt-get install -fy

    # add local source list
    local _packages_chroot="/config/packages.chroot"
    local _apt_flag="--no-install-recommends --yes -o Acquire::Retries=2 -o APT::Get::AllowUnauthenticated=true -o Acquire::AllowInsecureRepositories=1"
    [ -d ${_packages_chroot} ] && cd ${_packages_chroot} && dpkg-scanpackages . /dev/null | gzip > ./Packages.gz && cd -
    [ -f ${_packages_chroot}/Packages.gz ] && cat >> /etc/apt/sources.list <<EOF
deb [trusted=yes] file:${_packages_chroot} /
EOF
    apt-get update

    # Set deb source priorities
    cat > /etc/apt/preferences.d/kylin.pref << EOF
Package: *
Pin: origin "archive.kylinos.cn"
Pin-Priority: 400
EOF

    cat >/etc/hosts <<EOF
127.0.0.1 localhost
127.0.0.1 kylin
127.0.1.1 Kylin
EOF

    # update ca-certificates
    if ! [ -f /usr/share/ca-certificates/KY-WEB.crt ] && [ -f /usr/share/ca-certificates/KY-CA.crt ]
    then
        apt-get install -y ca-certificates
        pushd /usr/share/ca-certificates/
        [ -f /usr/share/ca-certificates/KY-WEB.crt ] && wget --quiet http://pki.kylin.com/ca/KY-WEB.crt
        [ -f /usr/share/ca-certificates/KY-CA.crt ] && wget --quiet http://pki.kylin.com/ca/KY-CA.crt
        popd
        echo -e 'KY-WEB.crt\nKY-CA.crt' >> /etc/ca-certificates.conf
        update-ca-certificates
    fi
}

# Step 2: Install deb listed in *.list.chroot
function install_pkg(){
    local _pkglist_dir="/config/package-lists"
    local _apt_flag="--no-install-recommends --yes -o Acquire::Retries=2 -o APT::Get::AllowUnauthenticated=true -o Acquire::AllowInsecureRepositories=1"
    local _pkglist_file=""

    export DEBIAN_FRONTEND=noninteractive

    apt install -fy

    # Installing console-base os
    _pkglist_file="console.list.chroot"
    [ -f ${_pkglist_dir}/${_pkglist_file} ] && apt install -fy ${_apt_flag} $(grep -v "^#" ${_pkglist_dir}/${_pkglist_file} | xargs)
    rm -f ${_pkglist_dir}/${_pkglist_file}

    # Installing fixed version packages
    _pkglist_file="fixed.list.chroot"
    [ -f ${_pkglist_dir}/${_pkglist_file} ] && apt install -fy ${_apt_flag} $(grep -v "^#" ${_pkglist_dir}/${_pkglist_file} | xargs)
    rm -f ${_pkglist_dir}/${_pkglist_file}

    # Installing ukui desktop environment
    _pkglist_file="ukui.list.chroot"
    [ -f ${_pkglist_dir}/${_pkglist_file} ] && apt install -fy ${_apt_flag} $(grep -v "^#" ${_pkglist_dir}/${_pkglist_file} | xargs)
    rm -f ${_pkglist_dir}/${_pkglist_file}

    # Installing kylin applingications
    _pkglist_file="kylinapplication.list.chroot"
    [ -f ${_pkglist_dir}/${_pkglist_file} ] && apt install -fy ${_apt_flag} $(grep -v "^#" ${_pkglist_dir}/${_pkglist_file} | xargs)
    rm -f ${_pkglist_dir}/${_pkglist_file}

    # Installing the remaining packages from the other list.chroot file
    for pkglist in ${_pkglist_dir}/*.list.chroot
    do
    	apt install -fy ${_apt_flag} $(grep -v "^#" ${pkglist}  | xargs)
    done

    # Clean local source list
    sed -i '/file:/d' /etc/apt/sources.list
}

# Step 3: Run kylin.chroot
function run_kylin_chroot() {
    . ${CURRENT_DIR}/kylin.chroot

    # reset resolve.conf
    chattr -i /etc/resolv.conf
}

# Step 4: Copy packages custom file
function copy_custom_files() {
    [ ! -d ${CURRENT_DIR}/includes.chroot ] && return 0
    local _files=(`ls -A ${CURRENT_DIR}/includes.chroot`)
    [ ${#_files[@]} -eq 0 ] && return 0

    cp -arf ${CURRENT_DIR}/includes.chroot/* /
}

set_deb_sources
install_pkg
run_kylin_chroot
copy_custom_files
