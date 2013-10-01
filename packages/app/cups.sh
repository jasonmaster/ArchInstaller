#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm `cat ../desktop/packages-cups.txt`

if [ `uname -m` == "x86_64" ]; then
    pacman -S --needed --noconfirm "lib32-libcups"
fi

systemctl enable cups.service
