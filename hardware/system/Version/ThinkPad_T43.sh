#!/usr/bin/env bash

# Thinkpad T43
#  - https://communities.bmc.com/communities/blogs/linux/2010/03/16/ubuntu-1004-and-the-t43
#  - http://pc-freak.net/blog/controlling-fan-with-thinkfan-on-lenovo-thinkpad-r61-on-debian-gnulinux-adjusting-proper-fan-cycling/
pacman -S --noconfirm --needed hdapsd tp_smapi
packer -S --noconfirm --noedit thinkfan hdaps-gl trousers tpm-tools tpmmanager
echo "options thinkpad_acpi fan_control=1" > /etc/modprobe.d/thinkpad_acpi.conf
# On the T43p the x-axis is inverted.
echo "options hdaps invert=1" > /etc/modprobe.d/hdaps.conf
# TODO
#  - use `tlp` to get a disk list. Only enable hdaps for rotational drives.
#  - Find a way to start `hdapsd-wrapper`
cp /usr/share/doc/thinkfan/examples/thinkfan.conf.thinkpad /etc/thinkfan.conf
systemctl enable thinkfan
systemctl enable tcsd

#TODO
# - hsfmodem
