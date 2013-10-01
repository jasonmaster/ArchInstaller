#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm artwiz-fonts libreoffice-calc libreoffice-common \
libreoffice-gnome libreoffice-impress libreoffice-math libreoffice-writer \
libreoffice-en-GB ttf-dejavu unoconv
pacman -S --needed --noconfirm hunspell-en hyphen-en mythes-en

# If you want the database tool uncomment this.
#pacman -S --needed --noconfirm libreoffice-base

# If you want the drawing tool uncomment this.
#pacman -S --needed --noconfirm libreoffice-draw
