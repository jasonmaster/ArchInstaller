#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

IS_INSTALLED=$(pacman -Qqm android-sdk-platform-tools)
if [ $? -ne 0 ]; then
    ./jdk6.sh
    packer -S --noedit --noconfirm android-sdk-platform-tools android-apktool
else
    echo "$(basename ${0} .sh) is already installed."
fi
