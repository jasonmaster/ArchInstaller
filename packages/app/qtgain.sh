#!/usr/bin/env bash

pacman -S --needed --noconfirm id3v2 mp3gain vorbisgain
packer -S --noedit --noconfirm qtgain aacgain-cvs
