# 主板二进制固件存放
此处用于存放对应板子的二进制文件，构建时通过如下三种渠道获取板级二进制镜像。

RK平台板级二进制镜像列表如下

```
./binary/
./binary/Image/
./binary/Image/boot.img
./binary/Image/parameter.txt
./binary/Image/uboot.img
./binary/Image/userdata.img
./binary/package-file
./binary/Image/MiniLoaderAll.bin
```

二进制固件以binary目录命令，里面存放除了rootfs.img以外的所有二进制镜像。由kypacker将其打包成rk平台的update镜像格式

## 渠道1: 通过源安装
默认情况以当前board配置为命令的deb包，如下
```
package_name="$(basename $(realpath .))-binary"
```
此时通过apt在构建时从源列表安装
```
apt install ${package_name}
```
通常这种情况属于默认源已经支持的硬件，故源中有此对应的包

## 渠道2: 通过本地deb安装
同上，默认可以由系统提供deb二进制，放置此目录，在系统构建时会主动进行安装，如下
```
package_name="$(basename $(realpath .))-binary_all.deb"
dpkg -i ${package_name}
```

## 渠道3: 通过放置binary目录安装
除了上述两种方式之外，可以主动在此放置binary目录，系统构建时会主动复制此目录，如下
```
cp -raf "$(realpath .)/binary" path_to_out
```

## 制作
本仓库提供binary_to_deb.sh脚本将binary目录打包成deb包，如下
```
../../../../script/binary_to_deb.sh $(realpath .) 
```
由此会生成名为`$(basename $(realpath .))-binary_all.deb`的deb包

## 注意
如此目录无deb包且无binary目录，则默认通过源进行安装
