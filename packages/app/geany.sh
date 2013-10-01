#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

pacman -S --needed --noconfirm geany geany-plugins
mkdir -p /home/${SUDO_USER}/.config/geany/filedefs
wget -qO- http://download.geany.org/contrib/oblivion2.tar.gz | tar zxv -C /home/${SUDO_USER}/.config/geany/filedefs/
chown -R ${SUDO_USER}: /home/${SUDO_USER}/.config/geany/filedefs
