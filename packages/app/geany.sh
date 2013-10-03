#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG=$(basename ${0} .sh)
MORE_PKGS="$(basename ${0} .sh)-plugins"

pacman -S --needed --noconfirm ${CORE_PKG} ${MORE_PKGS}

mkdir -p /home/${SUDO_USER}/.config/geany/filedefs
wget -qO- http://download.geany.org/contrib/oblivion2.tar.gz | tar zxv -C /home/${SUDO_USER}/.config/geany/filedefs/
chown -R ${SUDO_USER}: /home/${SUDO_USER}/.config/geany/filedefs
