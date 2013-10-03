#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG=""
MORE_PKGS="cvs bzr git mercurial subversion"

pacman -S --needed --noconfirm ${CORE_PKG} ${MORE_PKGS}

IS_INSTALLED=$(pacman -Qqm bzr-fastimport)
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm bzr-fastimport
fi
