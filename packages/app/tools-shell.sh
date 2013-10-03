#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG=""
MORE_PKGS="aria2 bash-completion colordiff curl ddrescue dmidecode glances \
hexedit htop laptop-detect lesspipe powertop screen tree"

pacman -S --needed --noconfirm ${CORE_PKG} ${MORE_PKGS}

IS_INSTALLED=$(pacman -Qqm dfc)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm dfc
fi
