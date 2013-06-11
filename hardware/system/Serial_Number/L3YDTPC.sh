#!/usr/bin/env bash

# My Thinkpad T43p

# I don't use PCMCIA slots anymore.
echo "blacklist pcmcia"       >  /etc/modprobe.d/blacklist-pcmcia.conf
echo "blacklist yenta_socket" >> /etc/modprobe.d/blacklist-pcmcia.conf

# I don't use parallel ports anymore.
echo "blacklist parport" >  /etc/modprobe.d/blacklist-parport.conf
echo "blacklist ppdev"   >> /etc/modprobe.d/blacklist-parport.conf
