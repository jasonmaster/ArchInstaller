#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --noconfirm --needed aria2 bash-completion colordiff curl ddrescue \
dmidecode glances hexedit htop laptop-detect lesspipe powertop screen tree

IS_INSTALLED=$(pacman -Qqm dfc)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm dfc
fi
