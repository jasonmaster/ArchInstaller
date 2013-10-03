#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG=$(basename ${0} .sh)
MORE_PKGS="libdiscid chromaprint"

pacman -S --needed --noconfirm ${CORE_PKG} ${MORE_PKGS}

IS_INSTALLED=$(pacman -Qqm ${CORE_PKG}-plugins)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm ${CORE_PKG}-plugins
fi
