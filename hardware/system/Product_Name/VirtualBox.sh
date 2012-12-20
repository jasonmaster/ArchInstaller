#!/usr/bin/env bash

source ../../../common.sh

pacman_install "virtualbox-guest-utils"
echo "vboxguest" >  /etc/modules-load.d/virtualbox-guest.conf
echo "vboxsf"    >> /etc/modules-load.d/virtualbox-guest.conf
echo "vboxvideo" >> /etc/modules-load.d/virtualbox-guest.conf
modprobe -a vboxguest vboxsf vboxvideo

# Enable access to Shared Folders
add_user_to_group ${SUDO_USER} vboxsf

# Synchronise date/time to the host
system_ctl stop ntpd.service
system_ctl disable ntpd.service
system_ctl enable vboxservice
system_ctl start vboxservice
