#!/usr/bin/env bash

if [ -f common.sh ]; then
    source common.sh
else
    echo "ERROR! Could not source 'common.sh'"
    exit 1
fi

# Errata
if [ -f /etc/modprobe.d/thinkfan.conf ]; then
    mv -f /etc/modprobe.d/thinkfan.conf /etc/modprobe.d/thinkpad_acpi.conf
fi

replaceinfile "BAY_POWEROFF_ON_BAT=0" "BAY_POWEROFF_ON_BAT=1" /etc/default/tlp

# Thinkpad T43
#  - https://communities.bmc.com/communities/blogs/linux/2010/03/16/ubuntu-1004-and-the-t43
#  - http://pc-freak.net/blog/controlling-fan-with-thinkfan-on-lenovo-thinkpad-r61-on-debian-gnulinux-adjusting-proper-fan-cycling/
pacman_install "fprintd hdapsd tp_smapi"
packer_install "thinkfan hdaps-gl"
echo "options thinkpad_acpi fan_control=1" > /etc/modprobe.d/thinkpad_acpi.conf
# On the T43p the x-axis is inverted.
echo "options hdaps invert=1" > /etc/modprobe.d/hdaps.conf
# TODO
#  - use `tlp` to get a disk list. Only enable hdaps for rotational drives.
#  - Find a way to start `hdapsd-wrapper`
cp /usr/share/doc/thinkfan/examples/thinkfan.conf.thinkpad /etc/thinkfan.conf
system_ctl enable thinkfan

#TODO - hsfmodem
