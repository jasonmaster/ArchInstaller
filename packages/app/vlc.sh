#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm vlc libbluray libdvdcss libdvdnav libdvdread
IS_INSTALLED=$(pacman -Qqm libaacs)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm libaacs
fi
mkdir -p /home/${SUDO_USER}/.config/aacs/
wget -c http://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg -O /home/${SUDO_USER}/.config/aacs/
chown -R ${SUDO_USER}:users /home/${SUDO_USER}/.config
