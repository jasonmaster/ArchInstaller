#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

IS_INSTALLED=$(pacman -Qqm `basename ${0} .sh`tab-ng-git)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm $(basename ${0} .sh)tab-ng-git
else
    echo "$(basename ${0} .sh) is already installed."
fi
