#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --noconfirm --needed aria2 glances
packer -S --noconfirm --noedit dfc
