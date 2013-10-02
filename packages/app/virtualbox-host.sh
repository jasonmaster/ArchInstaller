#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm virtualbox virtualbox-host-modules
packer -S --noedit --noconfirm virtualbox-ext-oracle
gpasswd -a ${SUDO_USER} vboxusers

modprobe -a vboxdrv vboxnetadp vboxnetflt

cat << MODULES > /etc/modules-load.d/virtualbox-host.conf
vboxdrv
vboxnetadp
vboxnetflt
MODULES
