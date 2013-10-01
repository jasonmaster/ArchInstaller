#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

./jdk6.sh
packer -S --noedit --noconfirm android-sdk-platform-tools android-apktool
