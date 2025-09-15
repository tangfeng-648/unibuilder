# Linux系统统一生态构建

此仓库可以根据指定源配置，从零完成linux发行版的系统构建，减少了操作系统的构建难度，加快了操作系统的开发效率。

同时，本仓库也可以通过配置源的方式集成第三方生态应用。

## 使用说明
本仓库基于 `dialog/whiptail/lxdialog` 实现交互式配置，无需关心操作系统内部配置细节。

交互式的配置信息存储在`.config`

脚本通过解析`.config`来进行操作系统构建，原则上，仅需提供系统的mirror和suite即可。

如果是麒麟系统操作系统，默认的mirror是：http://archive.kylinos.cn/kylin/KYLIN-ALL
