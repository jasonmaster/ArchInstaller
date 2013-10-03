#!/usr/bin/env bash

if [ `id -u` != 0 ]; then
    echo "ERROR! You must be root to execute this script."
    exit 1
fi

pacman -Syu --noconfirm

TEST_PACKER=`which packer`
if [ $? -eq 0 ]; then
    packer -Syu --noedit --noconfirm --auronly
    packer -Syu --noedit --noconfirm --auronly --devel
else
    echo "ERROR! 'packer' not found. AUR updating is being skipped."
    exit 0
fi
