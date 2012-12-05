#!/bin/bash

# Install packer
wget https://aur.archlinux.org/packages/pa/packer/packer.tar.gz -O /usr/local/src/packer.tar.gz
cd /usr/local/src
tar zxvf packer.tar.gz
cd packer
makepkg --asroot -s --noconfirm
pacman -U --noconfirm `ls -1t /usr/local/src/packer/*.pkg.tar.xz | head -1`

# Install pacman-color
packer -S --noconfirm --noedit pacman-color
