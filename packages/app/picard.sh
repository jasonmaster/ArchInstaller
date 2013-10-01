#!/usr/bin/env bash

pacman -S --needed --noconfirm picard libdiscid chromaprint
packer -S --noedit --noconfirm picard-plugins
