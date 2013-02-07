#!/usr/bin/env bash

if [ -f common.sh ]; then
    source common.sh
else
    echo "ERROR! Could not source 'common.sh'"
    exit 1
fi

check_root
check_sudo
check_archlinux

# Remove .git from /etc/skel
if [ -d /etc/skel/.git ]; then
    rm -rf /etc/skel/.git
fi

# Remove Chrony and ntpd. Replaced by `openntpd`.
HAS_CHRONY=`pacman -Qq chrony 2>/dev/null`
if [ ${HAS_CHRONY} -eq 0 ]; then
    system_ctl stop chrony
    system_ctl disable chrony
    pacman_remove "chrony"
fi

HAS_NTP=`pacman -Qq ntp 2>/dev/null`
if [ ${HAS_NTP} -eq 0 ]; then
    system_ctl stop ntp
    system_ctl disable ntp
    pacman_remove "ntp"
fi    
pacman_install "openntpd"
system_ctl enable openntpd
system_ctl start openntpd

# Remove ufw/gufw
HAS_GUFW=`which gufw 2>/dev/null`
if [ $? -eq 0 ]; then
    system_ctl stop ufw
    system_ctl disable ufw
    pacman_remove "gufw ufw"
fi

# Remove laptop-mode-tools. It has been replaced by TLP.
if [ -f /usr/lib/systemd/system/laptop-mode.service ]; then
    system_ctl stop laptop-mode
    system_ctl disable laptop-mode
    pacman_remove "laptop-mode-tools"
fi

# The screen brightness script is now generic-ish.
if [ -f /etc/pm/config.d/thinkpad-brightness ]; then
    rm -f /etc/pm/config.d/thinkpad-brightness
fi

# Migrate to the consistent naming scheme.
if [ -f /etc/modprobe.d/nobeep.conf ]; then
    mv -f /etc/modprobe.d/nobeep.conf /etc/modprobe.d/blacklist-pcspkr.conf
fi

if [ -f /etc/modules-load.d/cpufreq.conf ]; then
    mv -f /etc/modules-load.d/cpufreq.conf /etc/modules-load.d/acpi-cpufreq.conf
fi
