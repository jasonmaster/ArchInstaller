#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

IS_INSTALLED=$(pacman -Qqm `basename ${0} .sh`)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm $(basename ${0} .sh)
    echo "fs.inotify.max_user_watches = 131072" > /etc/sysctl.d/98-fs.inotify.max_user_watches.conf
else
    echo "$(basename ${0} .sh) is already installed."
fi
