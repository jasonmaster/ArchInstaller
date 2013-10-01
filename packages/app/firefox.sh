#!/usr/bin/env bash

pacman -S --needed --noconfirm firefox firefox-i18n-en-gb flashplugin
if [ `uname -m` == "x86_64" ]; then
    packer -S --noedit --noconfirm lib32-flashplugin
fi
