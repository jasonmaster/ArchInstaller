#!/usr/bin/env bash

UNAME_M=`uname -m`

# Uninstall nouveau
rm /etc/modprobe.d/nouveau.conf
pacman -Rdds --noconfirm nouveau-dri xf86-video-nouveau libtxc_dxtn
pacman -Rdds --noconfirm mesa-libgl
if [ "${UNAME_M}" == "x86_64" ]; then
    pacman -Rdds --noconfirm lib32-nouveau-dri lib32-mesa-libgl
fi

# Install nvidia
echo -en "\ny\n" | pacman -S --needed --noconfirm nvidia
if [ "${UNAME_M}" == "x86_64" ]; then
    pacman -S --noconfirm --needed lib32-nvidia-libgl
fi
