#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

if [ `uname -m` == "x86_64" ]; then
    PKGS="lib32-giflib lib32-libpng lib32-libldap lib32-gnutls lib32-lcms lib32-libxml2
         lib32-mpg123 lib32-openal lib32-v4l-utils lib32-libpulse lib32-alsa-plugins
         lib32-alsa-lib lib32-libjpeg-turbo lib32-libxcomposite lib32-libxinerama
         lib32-ncurses lib32-libcl"
else
    PKGS="giflib libpng libldap gnutls lcms libxml2 mpg123 openal v4l-utils libpulse
    alsa-plugins alsa-lib libjpeg-turbo libxcomposite libxinerama ncurses libcl"
fi

pacman -S --needed --noconfirm wine wine-mono wine_gecko winetricks samba ${PKGS}
packer -S --noedit --noconfirm ttf-ms-fonts
