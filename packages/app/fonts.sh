#!/usr/bin/env bash

pacman -S --needed --noconfirm `cat ../desktop/packages-ttf.txt`
packer -S --noedit --noconfirm ttf-ms-fonts ttf-unifont
fc-cache -f -v
