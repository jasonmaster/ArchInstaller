#!/usr/bin/env bash

# Download packer
wget http://aur.archlinux.org/packages/pa/packer/packer.tar.gz -O /usr/local/src/packer.tar.gz
if [ $? -ne 0 ]; then
    echo "ERROR! Couldn't downloading packer.tar.gz. Aborting packer install."
    exit 1
fi

# Make the package and install it
cd /usr/local/src
tar zxvf packer.tar.gz
cd packer
makepkg --asroot -s --noconfirm
pacman -U --noconfirm `ls -1t /usr/local/src/packer/*.pkg.tar.xz | head -1`

# Install pacman-color
packer -S --noconfirm --noedit pacman-color
