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

# example: ./script/binary_to_deb.sh config/platform/phytium/ft2000

# such as: config/platform/phytium/ft2000/
BINARY_PATH=$1
BINARY_DIR=binary

# such as: ft2000
NAME=$(basename ${BINARY_PATH})

# such as: ft2000-binary
DEB_NAME="${NAME}-${BINARY_DIR}"

[ $# -ne 1 ] && echo "Need deb package name" && exit 0

cd ${BINARY_PATH}

[ ! -d ${binary}/ ] && echo "Dir not found" && exit 0

tmp_dir=$(mktemp -d -p .)
[ ! -d ${tmp_dir}/DEBIAN/ ] && sudo mkdir -p ${tmp_dir}/DEBIAN/ 
cat > "${tmp_dir}/DEBIAN/control" <<EOF
Package: ${DEB_NAME}
Version: 1.0
Section: custom
Priority: optional
Architecture: all
Maintainer: Kylin Developers <kylin@kylinos.cn>
Description: A simple package
EOF

sudo mv ${BINARY_DIR} ${tmp_dir}
dpkg -b "${tmp_dir}/" "${DEB_NAME}_all.deb"
sudo mv ${tmp_dir}/${BINARY_DIR} ${BINARY_DIR}
sudo rm -rf ${tmp_dir}

cd -
