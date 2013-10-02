#!/usr/bin/env bash

echo "*** VirtualBox ***"
pacman -S --needed --noconfirm virtualbox-guest-utils

systemctl disable openntpd
systemctl enable vboxservice.service

echo 'vboxguest' >  /etc/modules-load.d/virtualbox-guest.conf
echo 'vboxsf'    >> /etc/modules-load.d/virtualbox-guest.conf
echo 'vboxvideo' >> /etc/modules-load.d/virtualbox-guest.conf

echo "Press any key to continue"
read
