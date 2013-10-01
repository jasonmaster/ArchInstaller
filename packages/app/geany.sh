#!/usr/bin/env bash

OBLIVION="http://download.geany.org/contrib/oblivion2.tar.gz"
pacman -S --needed --noconfirm geany geany-plugins
mkdir -p /home/${SUDO_USER}/.config/geany/filedefs
wget -qO- ${OBLIVION} | tar zxv -C /home/${SUDO_USER}/.config/geany/filedefs/
chown -R ${SUDO_USER}: /home/${SUDO_USER}/.config/geany/filedefs
