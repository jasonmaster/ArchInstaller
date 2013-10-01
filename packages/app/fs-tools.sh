#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --noconfirm --needed dosfstools jfsutils f2fs-tools btrfs-progs \
exfat-utils ntfs-3g reiserfsprogs xfsprogs nilfs-utils gpart mtools
