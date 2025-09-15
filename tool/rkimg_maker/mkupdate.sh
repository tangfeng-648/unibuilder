#!/bin/bash

# Self Test
CHIP=$1

usage()
{
    echo "Usage:
    ./$(basename $0) rk3399
    ./$(basename $0) rk3568
    ./$(basename $0) rk3588"
}

if ! [ "${CHIP}" = "rk3399" ] && ! [ "${CHIP}" = "rk3568" ] && ! [ "${CHIP}" = "rk3588" ]
then
	echo -e "\e[32mUnsupported Chip\e[0m"
	usage
	exit
fi

[ ! -d ./Image ] && echo "Cannot found Image directory" && exit

./afptool -pack ./ firmware_afp.img

<<!
# rk3399
./img_maker -rk3399 ./Image/MiniLoaderAll.bin  firmware_afp.img update.img
# rk3568
./img_maker -rk3588 ./Image/MiniLoaderAll.bin  firmware_afp.img update.img
# rk3588
./img_maker -rk3568 ./Image/MiniLoaderAll.bin  firmware_afp.img update.img
!
./img_maker -${CHIP} ./Image/MiniLoaderAll.bin  firmware_afp.img update.img
