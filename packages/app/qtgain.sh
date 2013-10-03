#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

IS_INSTALLED=$(pacman -Qqm `basename ${0} .sh`)
if [ $? -ne 0 ]; then
    pacman -S --needed --noconfirm id3v2 mp3gain vorbisgain
    packer -S --noedit --noconfirm $(basename ${0} .sh) aacgain-cvs
else
    echo "$(basename ${0} .sh) is already installed."
fi
