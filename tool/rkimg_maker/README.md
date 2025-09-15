# 打包工具afptool和img_maker
本目录为打包工具afptool和img_maker的源码目录，目前支持rk3399,rk3568，rk3588共三个平台。

## mkupdate.sh
该脚本用于二进制的自测试，运行该脚本需要满足如下条件

1. 当前目录有Image文件夹
2. 当前目录有package-file文件
3. parameter.txt 和 package-file文件需和平台对应
4. romcode.bin文件需要重命名为MiniLoaderAll.bin

## package-file

```
package-file    package-file
bootloader      Image/MiniLoaderAll.bin
parameter       Image/parameter.txt
trust           Image/trust.img
uboot           Image/uboot.img
boot            Image/boot.img
rootfs          Image/rootfs.img
```

## Image文件夹
Image文件夹为需要打包的实际二进制文件，将需要打包的二进制手动拷贝到当前目录的Image目录内后方可运行测试脚本

## update.img
生成的update.img在当前目录，请自行检查，如生成失败，请检查必要文件是否正确

## Windows工具
附带了一份Windows工具,可以通过Windows工具进行镜像烧录
```
windows-tool/DriverAssitant_v5.12.zip
windows-tool/RKDevTool_Release_v2.92.zip
```
## debug.sh
该脚本用于调试对比rkImageMaker和img_maker，因为img_maker为自行实现.故与rkImageMaker有差异

## 数据溢出
rkafp.h update_part的size,在分区比较大的时候，容易出现计算size溢出的问题,此问题当前不修复.
使用过程中注意即可
