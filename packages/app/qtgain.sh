#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm id3v2 mp3gain vorbisgain
packer -S --noedit --noconfirm qtgain aacgain-cvs
