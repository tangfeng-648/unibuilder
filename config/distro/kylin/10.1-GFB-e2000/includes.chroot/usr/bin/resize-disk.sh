#!/bin/bash

which resize2fs > /dev/null|| exit 0

if [ ! -f /var/local/.has_resized ]
then
	rootdev=$(blkid -t PARTLABEL="rootfs" -o device)
	userdev=$(blkid -t PARTLABEL="userdata" -o device)
	resize2fs ${rootdev} > /dev/null 2>&1
	resize2fs ${userdev} > /dev/null 2>&1

	touch /var/local/.has_resized

	# 改变root-rw的owner为kylin
	chown kylin:kylin /media/root-rw
fi

exit $?
