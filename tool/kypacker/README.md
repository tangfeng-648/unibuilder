# kyPacker
kyPacker是一个用于打包update镜像的工具，支持跨平台开发部署打包update.img镜像，此镜像可以通过瑞芯微开发工具升级固件

## 前置要求及示例
1. package-file 必存在于packDir目录(如`./tests/`)中，示例如下：
```
└─# ls -lh ./tests/
drwxrwx--- 1 root vboxsf 4.0K 12月 26 13:38 Image
-rwxrwx--- 1 root vboxsf  517 12月 26 14:25 package-file
```

2. 写在package-file中的文件描述必须真实存在

package-file文件描述如下:
```
└─# cat ./tests/package-file
package-file    package-file
bootloader      Image/rk3588_spl_loader_v1.11.112.bin
parameter       Image/parameter.txt
uboot           Image/uboot.img
boot            Image/boot.img
rootfs          Image/rootfs.img
userdata        Image/userdata.img
```

文件存放路径如下:
```
└─# ls -lh ./tests/Image/
-rwxrwx--- 1 root vboxsf 100M 12月 26 09:36 boot.img
-rwxrwx--- 1 root vboxsf  369 12月 21 17:15 parameter.txt
-rwxrwx--- 1 root vboxsf 457K 12月 26 09:24 rk3588_spl_loader_v1.11.112.bin
-rwxrwx--- 1 root vboxsf 100M 12月 26 09:36 rootfs.img
-rwxrwx--- 1 root vboxsf 4.0M 12月 22 14:38 uboot.img
-rwxrwx--- 1 root vboxsf 100M 12月 26 09:36 userdata.img
```
3. parameter.txt 的文件大小不可以超过0x3FF4个字节，可通过`ls -alh`查看
```
└─# ls -alh ./tests/package-file
-rwxrwx--- 1 root vboxsf 517 12月 26 14:25 ./tests/package-file
```

4. package-file的文件编码最好为utf-8, 如果是其它编码格式如ISO-8859、GTK等，请不要包含中文.
```
└─# file ./tests/package-file
./tests/package-file: UTF-8 Unicode text
```

5. parameter.txt文件中必须包含FIRMWARE_VER、MACHINE_MODEL、MACHINE_ID、mtdparts；mtdparts中的分区首地址0x00004000.
```
└─# cat ./tests/Image/parameter.txt
FIRMWARE_VER:1.0
MACHINE_MODEL:RK3588
MACHINE_ID:007
MANUFACTURER:RK3588
MAGIC:0x5041524B
ATAG:0x00200800
MACHINE:0xffffffff
CHECK_MASK:0x80
PWR_HLD:0,0,A,0,1
TYPE:GPT
CMDLINE:mtdparts=rk29xxnand:0x00004000@0x00004000(uboot),0x00080000@0x00008000(boot:bootable),0x06000000@0x00088000(rootfs),-@0x06088000(userdata:grow)
uuid:rootfs=614e0000-0000-4b53-8000-1d28000054a9
```
6. python解释器版本 >=3.8

## 使用方法
### 打包生成firmware.img
参考工具的usage如下：
```
usage: kyPacker.py afptool pack [-h] dir firmware

positional arguments:
  dir         dir that contains package-file
  firmware    firmware.img packed by afptool

options:
  -h, --help  show this help message and exit


eg: kyPacker.py afptool pack  ./tests  ./tests/Image/firmware.img
```

运行后firmware.img将生成在./tests/Image/下

### 打包生成update.img
参考工具的usage如下：
```
usage: kyPacker.py imgmker pack [-h] -os_type {androidos,rkos} [-storage {FLASH,EMMC,SD,SPINAND,SPINOR,SATA,PCIE}] chiptype bootloader firmware

positional arguments:
  chiptype              set chip type, eg: RK3588
  bootloader            bootloader.bin
  firmware              firmware.img packed by afptool

options:
  -h, --help            show this help message and exit
  -os_type {androidos,rkos}
                        set os type
  -storage {FLASH,EMMC,SD,SPINAND,SPINOR,SATA,PCIE}
                        set storage type


eg: kyPacker.py imgmker pack RK3588 ./tests/Image/bootloader.img ./tests/Image/firmware.img -os_type androidos
```

运行后update.img将生成在当前目录下

## 注意事项
1. 处理大文件时，纯python实现的RK CRC32会相当耗时，可参考kyPacker.py中的注释将CRC算法转换成动态库，缩短打包时间.
使用编译命令 ```g++ -shared -o librkcrc32.so -fPIC rkcrc32.cpp```
```
└─# cat rkcrc32.cpp  (完整码表见kyPacker.py|rkcrc32.cpp)


#include <stdint.h>

extern "C" {
    uint32_t rkcrc_crc32(const unsigned char *data, int length, uint32_t crc);
}

uint32_t _crc32_table[256] = {
        0x00000000, 0x04c10db7, 0x09821b6e, 0x0d4316d9, ...
};

uint32_t rkcrc_crc32(const unsigned char *data, int length, uint32_t crc) {
    crc = crc & 0xFFFFFFFF;
    for (int i = 0; i < length; i++) {
        crc = _crc32_table[data[i] ^ (crc >> 24)] ^ ((crc << 8) & 0xFFFFFFFF);
    }
    return crc & 0xFFFFFFFF;
}
```

2. 当前目录下存在librkcrc32.so时，py会使用动态库的方式进行CRC的计算.
