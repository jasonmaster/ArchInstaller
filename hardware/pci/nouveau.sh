#!/usr/bin/env bash

UNAME_M=`uname -m`
KMS="nouveau"
KMS_OPTIONS="modeset=1"
DRI="nouveau-dri"
DDX="xf86-video-nouveau"
DECODER="libva-vdpau-driver"

pacman -S --noconfirm --needed ${DRI} ${DECODER}
if [ "${UNAME_M}" == "x86_64" ]; then
    pacman -S --noconfirm --needed lib32-${DRI} lib32-mesa-libgl
fi
echo "options ${KMS} ${KMS_OPTIONS}" > "${KMS}.conf"
