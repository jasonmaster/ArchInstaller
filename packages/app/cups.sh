#!/usr/bin/env bash

pacman -S --needed --noconfirm `cat ../desktop/packages-cups.txt`
if [ `uname -m` == "x86_64" ]; then
    pacman -S --needed --noconfirm "lib32-libcups"
fi
systemctl enable cups.service

