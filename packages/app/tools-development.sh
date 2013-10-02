#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

if [ `uname -m` == "x86_64" ]; then
    DEVEL="multilib-devel"
else    
    DEVEL="base-devel"
fi
pacman -S --needed --noconfirm ${DEVEL} devtools
