#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG="devtools"

if [ `uname -m` == "x86_64" ]; then
    MORE_PKGS="multilib-devel"
else    
    MORE_PKGS="base-devel"
fi

pacman -S --needed --noconfirm ${CORE_PKG} ${MORE_PKGS}
