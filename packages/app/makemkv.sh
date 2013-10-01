#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

packer -S --noedit --noconfirm makemkv
if [ `uname -m` == "x86_64" ]; then
    pacman -S --noedit --noconfirm lib32-glibc
fi
