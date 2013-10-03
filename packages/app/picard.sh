#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm picard libdiscid chromaprint
IS_INSTALLED=$(pacman -Qqm `basename ${0} .sh`-plugins)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm $(basename ${0} .sh-plugins)
fi
