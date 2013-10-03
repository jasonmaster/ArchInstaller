#!/usr/bin/env bash

if [ `id -u` -ne 0 ]; then
    echo "ERROR! `basename ${0}` must be executed as root."
    exit 1
fi

CORE_PKG=$(basename ${0} .sh)
MORE_PKGS=""

IS_INSTALLED=$(pacman -Qqm ${CORE_PKG})
if [ $? -ne 0 ]; then
    packer -S --noedit --noconfirm ${CORE_PKG} ${MORE_PKGS}
else
    echo "${CORE_PKG} is already installed."
fi

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
