ls
#!/usr/bin/env bash

pacman -S --needed --noconfirm vlc libbluray libdvdcss libdvdnav libdvdread
packer -S --noedit --noconfirm libaacs
mkdir -p /home/${SUDO_USER}/.config/aacs/
wget -c http://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg -O /home/${SUDO_USER}/.config/aacs/
chown -R ${SUDO_USER}:users /home/${SUDO_USER}/.config
