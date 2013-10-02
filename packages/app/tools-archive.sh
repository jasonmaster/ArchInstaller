#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --noconfirm --needed arj cabextract bzip2 gzip lha lzo2 lzop rpmextract \
sharutils tar unace unrar unzip uudeview xz zip
