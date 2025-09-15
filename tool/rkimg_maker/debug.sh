#!/bin/bash
make

declare -i length

./afptool -pack ./ Image/update.img
./rkImageMaker -RK330C Image/MiniLoaderAll.bin Image/update.img update_rk.img -os_type:androidos
./img_maker -rk3399 Image/MiniLoaderAll.bin Image/update.img update_ky.img

length=`ls -l update_rk.img | awk '{print $5}'`
let offset=length-512
echo "offset=$offset length=$length"

hexdump update_ky.img -C -n 512 > ky
hexdump update_ky.img -C -n 512 -s "${offset}" >> ky
hexdump update_rk.img -C -n 512 > rk
hexdump update_rk.img -C -n 512 -s "${offset}" >> rk

# vimdiff ky rk 
