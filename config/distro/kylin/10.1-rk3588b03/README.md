### 平台的配置脚本目录
### 文件介绍
1. main.sh 是配置的主脚本,由rootfs.sh执行
2. package-lists 是包列表文件夹
3. kylin.chroot 是配置的脚本

### 定制步骤
1. 在main.sh 中修改平台的源地址，如修改PLATFORM_SOURCE_LIST_COMMON和PLATFORM_SOURCE_LIST_X11
2. 在package-lists目录内增加XXXX.list.chroot文件，里面写入需要安装的deb包名字
3. 在packages.chroot目录内新增特殊的deb安装包
4. 在kylin.chroot 运行平台的定制修改

