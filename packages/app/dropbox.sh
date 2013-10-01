#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

packer -S --noedit --noconfirm dropbox
echo "fs.inotify.max_user_watches = 131072" > /etc/sysctl.d/98-dropbox.conf
