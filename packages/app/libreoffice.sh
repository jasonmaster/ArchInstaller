#!/usr/bin/env bash

pacman -S --needed --noconfirm artwiz-fonts libreoffice-calc libreoffice-common \
libreoffice-gnome libreoffice-impress libreoffice-math libreoffice-writer \
libreoffice-en-GB ttf-dejavu unoconv
pacman -S --needed --noconfirm hunspell-en hyphen-en mythes-en

# If you want the database tool uncomment this.
#pacman -S --needed --noconfirm libreoffice-base

# If you want the drawing tool uncomment this.
#pacman -S --needed --noconfirm libreoffice-draw
