#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm banshee gstreamer0.10-good-plugins gstreamer0.10-ugly-plugins gstreamer0.10-ffmpeg
