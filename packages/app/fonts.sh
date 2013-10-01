#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm `cat ../desktop/packages-ttf.txt`
packer -S --noedit --noconfirm ttf-ms-fonts ttf-unifont
fc-cache -f -v
