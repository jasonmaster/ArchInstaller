#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm firefox firefox-i18n-en-gb flashplugin

if [ `uname -m` == "x86_64" ]; then
    IS_INSTALLED=$(pacman -Qqm lib32-flashplugin)
    if [ $? -ne 0 ]; then
        packer -S --noedit --noconfirm lib32-flashplugin
    fi
fi
