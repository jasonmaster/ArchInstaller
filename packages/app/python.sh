#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm python-pip python-setuptools python-virtualenv
pacman -S --needed --noconfirm python2-pip python2-distribute python2-virtualenv python-virtualenvwrapper
