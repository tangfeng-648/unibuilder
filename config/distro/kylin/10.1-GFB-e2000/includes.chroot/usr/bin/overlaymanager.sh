#!/bin/bash
DATE=$(date +%Y%m%d%H)

info(){
       echo -e "\033[34m[Kylin]:$1 \033[0m"
}

must_root(){
	if [ `whoami` != "root" ]
	then
		info "请使用root用户执行命令"
	fi
}

usage(){
    info "Usage: "
    info "       $0 -commit/-c #提交"
    info "       $0 -ghost/-g  #一键ghost"
    info "       $0 -ghost_onlyupper/-go  #仅备份commit"
    info "       $0 -restore/-r  #系统还原"
    info "       $0 -update/-u #更新系统"
    info "       $0 -backup/-back #备份成ext4系统"
    info "       $0 -y #打开自动清理"
    info "       $0 -n #关闭自动清理"
    info "       $0 -boot/-b boot.img #升级内核"
    info "       $0 -ext4/-e #将squashfs转换成ext4"
    info "       $0 -v #查看版本"
}

update_boot(){
	[ "$1" == "" ] && info "没有输入文件" && return
	[ ! -e $1 ] && info "没有这样的文件" && return

	magic=`hexdump -n 8 $1 -e '1/8 "%08s"' -e '"\n"'`
	if [ "${magic}" == "ANDROID!" ];then
		[ -e /dev/disk/by-partlabel/boot ] && dd if=$1 of=/dev/disk/by-partlabel/boot
		sync
		info "内核更新成功,重启后生效"
	else
		info "不是boot格式文件"
	fi
}

# 通过commit目录判断字符文件,删掉对应root下的目录
overlayfs_delete_dir(){
        local root=$1
        local root_rw=/media/root-rw/
        for i in `find ${root_rw}/commit/ -type c -print`
        do
                tmp=${i#*/}
                tmp=${tmp#*/}
                tmp=${tmp#*/}
                tmp=${tmp#*/}
                [ -d ${root}/${tmp} ] && rm -rf ${root}/${tmp} && echo "success delete ${root}/${tmp}"
		rm -f $i
        done
}

get_rootfs_block(){
	local rootblk=rootfs.img

	if [ "${1}" != "" ];then
		rootblk=$1
	fi

	info "第一步:创建rootfs分区文件"
	dd if=/dev/zero of=${rootblk} count=2048
	mkfs.ext4 ${rootblk}
	resize2fs ${rootblk} 12G
	inode=`expr 12 \* 1024 \* 1024 / 16`
	mkfs.ext4 -F -N ${inode} ${rootblk}
	temp_dir=`mktemp -d`
	mount ${rootblk} ${temp_dir}
	info "第二步:拷贝文件到rootfs分区中"
	cp -rpf /media/root-ro/* "${temp_dir}"
	overlayfs_delete_dir "${temp_dir}"
	cp -rpf /media/root-rw/commit/* "${temp_dir}"
	sync
	info "第三步:卸载目录,同步数据"
	umount ${temp_dir}
	rm -r temp_dir
	e2fsck -fy ${rootblk}
	resize2fs ${rootblk} -M
	file ${rootblk}
	info "系统备份成果,文件为:${rootblk}"
}

convert_to_ext4(){
	local rootrw=/media/root-rw/
	local rootro=/media/root-ro/

	local root_partition=`blkid -s PARTLABEL | grep "rootfs" |awk -F: '{print $1}' | head -n 1`
	local user_partition=`blkid -s PARTLABEL | grep "userdata" |awk -F: '{print $1}' | head -n 1`
	if [ "${user_partition}" == "" ] || [ "${root_partition}" == "" ]
	then
		info "无rootfs分区或userdata分区,跳过"
		return
	fi

	info "即将转换${root_partition}到${user_partition},分区类型从`blkid -o value -s TYPE ${root_partition}`到`blkid -o value -s TYPE ${user_partition}`"

	mountpoint -q ${rootrw} || mount ${root_partition} ${rootro}
	mountpoint -q ${rootro} || mount ${user_partition} ${rootrw}

	rsync -az ${rootro}/ "${rootrw}"
        #cp -rpf ${rootro}/* "${rootrw}"
        overlayfs_delete_dir "${rootrw}"
	rsync -az ${rootrw}/commit/ "${rootrw}"
        #cp -rpf ${rootrw}/commit/* "${rootrw}"
        sync

	# if partition=/dev/mmcblk1p3 then partnum=3
	local part=${root_partition%[a-z][0-9]}
	local partnum=${root_partition#${part}[a-z]} # partnum < 10
	sgdisk -c ${partnum}:"backup" ${part}

	part=${user_partition%[a-z][0-9]}
	partnum=${user_partition#${part}[a-z]} # partnum < 10
	sgdisk -c ${partnum}:"rootfs" ${part}

	info "即将重启"
}

main() {
	local option=${1#*-}
	local user="kylin"
	local dir="/home/$user/.config/overlay"

	if [ ! -d ${dir} ];then
		mkdir -p ${dir}
		chown ${usr}:${usr} ${dir}
	fi

	case $option in
	    y)
			local root_rw_commit=/media/root-rw/commit
			local cleanfile_t=${dir}/disable_overlayfs_autoclean
			local cleanfile_c=${root_rw_commit}/${cleanfile_t}
			[ -e ${cleanfile_c} ] && rm -f ${cleanfile_c}
			[ -e ${cleanfile_t} ] && rm -f ${cleanfile_t}
	        info "打开自动清理"
	        ;;
	    n)
	        touch "${dir}/disable_overlayfs_autoclean"
	        info "关闭自动清理"
	        ;;
	    commit|c)
	        touch "${dir}/mk_snapshot_$DATE"
	        info "重启将提交所有改动"
	        ;;
	    ghost|g)
	        touch "${dir}/mk_ghost_$DATE"
	        info "重启将备份系统"
	        ;;
	    ghost_upper|go)
	        touch "${dir}/mk_ghost_onlyupper_$DATE"
	        info "重启将备份commit"
		;;
	    update|u)
	        touch "${dir}/mk_update_$DATE"
		info "重启将更新系统"
		info "请确保更新U盘是否插入"
		;;
	    boot|b)
		update_boot $2
		;;
	    restore|r)
		touch "${dir}/mk_restore_$DATE"
		info "重启将恢复还原系统"
		;;
	    backup|back)
		get_rootfs_block $2
		;;
	    ext4|e)
		convert_to_ext4
		;;
	    help|h)
		usage
		;;
		v|version)
			info "overlay shell version:1.0.2"
		;;
	    *)
	        info "没有这样的参数"
	        usage
	        exit 1
	        ;;
	esac
}

main $1 $2
