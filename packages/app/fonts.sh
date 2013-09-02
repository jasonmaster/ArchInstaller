#!/usr/bin/env bash

pacman -S --noconfirm --needed ttf-dejavu ttf-bitstream-vera \
ttf-droid ttf-liberation ttf-ubuntu-font-family
packer -S -noedit --noconfirm ttf-fixedsys-excelsior-linux \
ttf-ms-fonts ttf-source-code-pro ttf-unifont

