#!/usr/bin/env bash

packer -S --noedit --noconfirm makemkv
if [ `uname -m` == "x86_64" ]; then
    pacman -S --noedit --noconfirm lib32-glibc
fi
