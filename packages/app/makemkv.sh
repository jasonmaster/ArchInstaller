#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG=$(basename ${0} .sh)
MORE_PKGS="lib32-glibc"

IS_INSTALLED=$(pacman -Qqm ${CORE_PKG})
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm ${CORE_PKG}
    if [ `uname -m` == "x86_64" ]; then
        pacman -S --needed --noconfirm ${MORE_PKGS}
    fi
else
    echo "${CORE_PKG} is already installed."
fi
