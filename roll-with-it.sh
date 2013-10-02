#!/usr/bin/env bash

pacman -Syu --noconfirm

TEST_PACKER=`which packer`
if [ $? -eq 0 ]; then
    packer -Syu --noedit --noconfirm --auronly
    packer -Syu --noedit --noconfirm --auronly --devel
else
    echo "ERROR! 'packer' not found. AUR updating is being skipped."
    exit 0
fi
