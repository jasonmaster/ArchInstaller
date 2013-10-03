#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG=$(basename ${0} .sh)
MORE_PKGS="${CORE_PKG}-i18n-en-gb flashplugin"

pacman -S --needed --noconfirm ${CORE_PKG} ${MORE_PKGS}

if [ `uname -m` == "x86_64" ]; then
    IS_INSTALLED=$(pacman -Qqm lib32-flashplugin)
    if [ $? -ne 0 ]; then
        packer -S --noedit --noconfirm lib32-flashplugin
    fi
fi
