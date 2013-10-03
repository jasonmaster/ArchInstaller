#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

# Install
pacman -S --needed --noconfirm virtualbox virtualbox-host-modules
IS_INSTALLED=$(pacman -Qqm virtualbox-ext-oracle)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm virtualbox-ext-oracle
fi

# Configure
gpasswd -a ${SUDO_USER} vboxusers
modprobe -a vboxdrv vboxnetadp vboxnetflt
cat << MODULES > /etc/modules-load.d/virtualbox-host.conf
vboxdrv
vboxnetadp
vboxnetflt
MODULES
