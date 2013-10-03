#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG=""
MORE_PKGS="cifs-utils btrfs-progs dosfstools jfsutils f2fs-tools exfat-utils \
ntfsprogs ntfs-3g reiserfsprogs xfsprogs nilfs-utils gpart mtools"

pacman -S --needed --noconfirm ${CORE_PKG} ${MORE_PKGS}
