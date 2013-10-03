#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

IS_INSTALLED=$(pacman -Qqm `basename ${0} .sh`)
if [ $? -ne 0 ]; then
    ./jre6.sh
    packer -S --noedit --noconfirm $(basename ${0} .sh)
    wget -c ftp://ftp.supermicro.com/CDR-0010_2.10_IPMI_Server_Managment/res/smcc.ico -O /opt/SUPERMICRO/IPMIView/smcc.ico

    cat << DESKTOP > /usr/share/applications/ipmiview.desktop
[Desktop Entry]
Version=1.0
Exec=/opt/IPMIView/IPMIView20.sh
Icon=/opt/SUPERMICRO/IPMIView/smcc.ico
Name=IPMI View
Comment=IPMI View
Encoding=UTF-8
Terminal=false
Type=Application
Categories=System;
DESKTOP
else
    echo "$(basename ${0} .sh) is already installed."
fi

