#!/usr/bin/env bash

pacman -S --needed --noconfirm virtualbox-guest-modules
read
depmod -a
echo "vboxguest" >  /etc/modules-load.d/virtualbox-guest.conf
echo "vboxsf"    >> /etc/modules-load.d/virtualbox-guest.conf
echo "vboxvideo" >> /etc/modules-load.d/virtualbox-guest.conf
pacman -S --needed --noconfirm virtualbox-guest-utils
read

# Synchronise date/time to the host
if [ "${HOSTNAME}" != "archiso" ]; then
    # Only do this when  NOT running from the install media
    modprobe -a vboxguest vboxsf vboxvideo
    gpasswd -a ${SUDO_USER} vboxsf
    systemctl stop openntpd
    systemctl start vboxservice
fi
systemctl disable openntpd
systemctl enable vbo
VBoxClient-all
read
