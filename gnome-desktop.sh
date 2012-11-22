#!/usr/bin/env bash

sp="/-\|"
log="${PWD}/`basename ${0}`.log"
rm $log 2>/dev/null

if [ -f common.sh ]; then
    source common.sh
else    
    echo "ERROR! Could not source 'common.sh'"
    exit 1
fi

check_root
check_sudo
check_archlinux
check_hostname
check_domainname
check_ip
check_cpu
check_vga
pacman_sync

INSTALL_BROWSERS=0
INSTALL_LIBREOFFICE=1
INSTALL_DEVELOPMENT=1
INSTALL_VIRTUALBOX=0
INSTALL_CHAT_APPS=1
INSTALL_GRAPHIC_APPS=1
INSTALL_3D_APPS=0
INSTALL_PHOTO_APPS=1
INSTALL_MUSIC_APPS=1
INSTALL_VIDEO_PLAYER_APPS=1
INSTALL_VIDEO_EDITOR_APPS=0
INSTALL_REMOTE_DESTOP_APPS=1
INSTALL_DOWNLOAD_APPS=1
INSTALL_ZIMBRA_DESKTOP=0
INSTALL_IPMIVIEW=0
INSTALL_RAIDAR=0
INSTALL_WINE=1
INSTALL_BACKUP_APPS=0

# Configure init things
update_early_modules ${VIDEO_KERNEL}

# Xorg
pacman_install_group "xorg"
pacman_install_group "xorg-apps"

if [ -n "${VIDEO_DRIVER}" ]; then
    pacman_install "xf86-video-${VIDEO_DRIVER} ${VIDEO_DRIVER}-dri ${VIDEO_ACCEL}" "${VIDEO_DRIVER}"
    if [ "${CPU}" == "x86_64" ]; then
        pacman_install "lib32-${VIDEO_DRIVER}-dri"
    fi
fi

#Touch Screen
# - http://www.x.org/archive/X11R7.5/doc/man/man4/evdev.4.html
# - https://bbs.archlinux.org/viewtopic.php?id=126208
# Is there an eGalax touch screen available?
TOUCH_SCREEN=0
EGALAX=`lsusb | grep -q 0eef:0001`
if [ $? -eq 0 ]; then
    TOUCH_SCREEN=1
    echo " [!] eGalax touch screen detected"           
    if [ ! -f /etc/modprobe.d/egalax.conf ]; then    
        packer_install "xinput_calibrator"
        rmmod usbtouchscreen 2>/dev/null
        
        cat >/etc/modprobe.d/egalax.conf<<ENDEGALAX
# Do not load the 'usbtouchscreen' module, as it conflicts with eGalax
blacklist usbtouchscreen
#options usbhid quirks=0xxeef.0x0001:0x0040 # <-- Not required since 2.6.32-ish here for reference
ENDEGALAX

        cat >/etc/X11/xorg.conf.d/99-calibration.conf<<ENDCALIB
Section "InputClass"
    Identifier      "calibration"
    MatchProduct    "eGalax Inc. USB TouchController"
    Option          "Calibration"   "3996 122 208 3996"
    Option          "InvertY" "1"
    Option          "SwapAxes" "0"
EndSection
ENDCALIB
    fi
fi

#xinput set-int-prop "eGalax Inc. Touch" "Evdev Axis Calibration" 32 3975 107 -147 3582

# Fonts
pacman_install "ttf-bitstream-vera ttf-liberation ttf-ubuntu-font-family"
packer_install "ttf-fixedsys-excelsior-linux ttf-ms-fonts ttf-source-code-pro"

# Gnome
pacman_install_group "gnome"
pacman_install_group "gnome-extra"
pacman_install_group "telepathy"
pacman_install "epiphany-extensions gedit-plugins gnome-tweak-tool terminator"
packer_install "gip gufw"
if [ ${TOUCH_SCREEN} -eq 1 ]; then
    pacman_install "xournal"
fi
systemctl enable gdm.service

# Network Manager
pacman_install "networkmanager-pptp"
systemctl enable NetworkManager.service

# Gstreamer
pacman_install "gst-plugins-base gst-plugins-base-libs gst-plugins-good \
gst-plugins-bad gst-plugins-ugly gst-ffmpeg" "GStreamer"

# Printing 
pacman_install "cups foomatic-db foomatic-db-engine foomatic-db-nonfree \
foomatic-filters gutenprint"
systemctl enable cups.service

# Dropbox
packer_install "dropbox"

# Flash
pacman_install "nspluginwrapper flashplugin"
nspluginwrapper -v -n -a -i
#For 64-bit machines, you'll need to install 
if [ "${CPU}" == "x86_64" ]; then
    pacman_install "lib32-flashplugin"

# Google Earth
packer_install "google_earth"

# Browsers
if [ ${INSTALL_BROWSERS} -eq 1 ]; then
    pacman_install "chromium firefox opera"
    packer_install "chromium-stable-libpdf"
fi

# LibreOffice
if [ ${INSTALL_LIBREOFFICE} -eq 1 ]; then
    pacman_install "artwiz-fonts libreoffice-base libreoffice-calc \
    libreoffice-common libreoffice-draw libreoffice-gnome libreoffice-impress \
    libreoffice-math libreoffice-writer libreoffice-en-GB ttf-dejavu unoconv" "LibreOffice"
    pacman_install "hunspell-en hyphen-en mythes-en" "Spelling & Grammar"
    packer_install "glabels"    
fi

# Development
if [ ${INSTALL_DEVELOPMENT} -eq 1 ]; then
    pacman_install "python-pip python-distribute python-virtualenv"
    pacman_install "python2-pip python2-distribute python2-virtualenv \
    python-virtualenvwrapper"    
    
    pacman_install "meld poedit pygtksourceview2"
    packer_install "kiki-re retext sqlite-manager winpdb wxhexeditor"
    packer_install "jre6 android-sdk-platform-tools"
    packer_install "upslug2"

    # Gedit
    packer_install "gedit-advancedfind"
    packer_install "gedit-smart-highlighting-plugin"
    chmod 666 /usr/lib/gedit/plugins/smart_highlight/config.xml
    packer_install "gdp"
    packer_install "gedit-source-code-browser"
    packer_install "gedit-django-project"

    # Mine
    # gedit-schemer-plugin
    # gedit-imitation-plugin
    # gedit-open-uri-context-menu-plugin    
    
    pacman_install "pgadmin3"
    packer_install "wingide"    
fi

if [ ${INSTALL_VIRTUALBOX} -eq 1 ]; then
    # Virtualbox
    pacman_install "virtualbox virtualbox-additions virtualbox-modules virtualbox-source"
    packer_install "virtualbox-ext-oracle"
    # FIXME - do this for all users
    add_user_to_group ${SUDO_USER} vboxusers
    
    echo "vboxdrv" >     /etc/modules-load.d/virtualbox.conf
    echo "vboxnetadp" >> /etc/modules-load.d/virtualbox.conf
    echo "vboxnetflt" >> /etc/modules-load.d/virtualbox.conf
fi

# Chat
if [ ${INSTALL_CHAT_APPS} -eq 1 ]; then
    # TODO - Skype notifications
    pacman_install "skype"
fi    

# Graphics
if [ ${INSTALL_GRAPHIC_APPS} -eq 1 ]; then
    pacman_install "gcolor2 gimp simple-scan"
fi    

# 3D Graphics
if [ ${INSTALL_3D_APPS} -eq 1 ]; then
    packer_install "sweethome3d"
FI    

# Photo Managers
if [ ${INSTALL_PHOTO_APPS} -eq 1 ]; then
    pacman_install "shotwell"
fi

# Music
#  - TODO : Choose between banshee or clementine
if [ ${INSTALL_MUSIC_APPS} -eq 1 ]; then
    pacman_install "banshee mp3gain"
    pacman_install "picard chromaprint libdiscid"
    packer_install "picard-plugins google-musicmanager nuvolaplayer"

    # FIXME
    #  - Do this for all users
    # Use the 'standard' preset by default. This preset should generally be
    # transparent to most people on most music and is already quite high in quality.
    # The resulting bitrate should be in the 170-210kbps range, according to music
    # complexity.
    sudo -u ${SUDO_USER} gconftool-2 --type string --set /system/gstreamer/0.10/audio/profiles/mp3/pipeline "audio/x-raw-int,rate=44100,channels=2 ! lame name=enc preset=1001 ! id3v2mux"    
fi

# Video
if [ ${INSTALL_VIDEO_PLAYER_APPS} -eq 1 ]; then    
    pacman_install "mediainfo mkvtoolnix-cli" #mkvtoolnix-gtk
    packer_install "get_iplayer tsmuxer-gui"
    # DVD & Blu-Ray
    pacman_install "libbluray libdvdread libdvdcss libdvdnav"
    packer_install "libaacs"
    #mkdir /home/${SUDO_USER}   
    #cd ~/.config/aacs/ && wget http://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg    

    pacman_install "devede handbrake vlc"
    packer_install "arista-transcoder makemkv"    
fi

if [ ${INSTALL_VIDEO_EDITOR_APPS} -eq 1 ]; then    
    pacman_install "openshot"
fi

# Remote Desktop
if [ ${INSTALL_REMOTE_DESKTOP_APPS} -eq 1 ]; then
    #pacman_install "remmina freerdp nxproxy" # Becoming unstable
    pacman_install "nxclient rdesktop tigervnc"
fi

# Download Managers
if [ ${INSTALL_DOWNLOAD_APPS} -eq 1 ]; then
    pacman_install "clamz filezilla ncftp nfoview terminus-font transmission-gtk tucan"

    # FIXME - do this for all users
    # Update transmission config
    if [ -f /home/${SUDO_USER}/.config/transmission/settings.json ]; then
        replaceinfile '"blocklist-enabled": false' '"blocklist-enabled": true' /home/${SUDO_USER}/.config/transmission/settings.json
        replaceinfile "www\.example\.com\/blocklist" "list\.iblocklist\.com\/\?list=bt_level1&fileformat=p2p&archiveformat=gz" /home/${SUDO_USER}/.config/transmission/settings.json
    fi

    packer_install "filezilla-faenza-icons filezilla-gnome-colors-icons filezilla-tango-icons pymazon"
    wget_install_generic "http://aux.iconpedia.net/uploads/20468992281869356568.png" /usr/share/pixmaps
    system_application_menu "pymazon" "pymazon %f" "/usr/share/pixmaps/20468992281869356568.png" "Amazon MP3 Downloader" "Network;WebBrowser;"
    packer_install "torrent-search"    
    packer_install "steadyflow"    
fi

# Backup
if [ ${INSTALL_BACKUP_APPS} -eq 1 ]; then
    pacman_install "deja-dup rsnapshot"
fi

# Wine 
if [ ${INSTALL_WINE} -eq 1 ]; then
    pacman_install "wine winetricks"
fi    

# IPMIView
if [ ${INSTALL_IPMIVIEW} -eq 1 ]; then
    packer_install "ipmiview"
    if [ ! -f /opt/SUPERMICRO/IPMIView/smcc.ico ]; then
        wget_install_generic "ftp://ftp.supermicro.com/CDR-0010_2.10_IPMI_Server_Managment/res/smcc.ico" /opt/SUPERMICRO/IPMIView/
        system_application_menu "ipmiview" "/opt/IPMIView/IPMIView20.sh" "/opt/SUPERMICRO/IPMIView/smcc.ico" "IPMI View" "System;"
    fi        
fi

# ReadyNAS RAIDar
if [ ${INSTALL_RAIDAR} -eq 1 ]; then
    if [ ! -e /opt/RAIDar/RAIDar ]; then
        wget_install_generic http://www.readynas.com/download/RAIDar/RAIDar_Linux.sh /tmp
        chmod 755 RAIDar_Linux.sh
        bash ./RAIDar_Linux.sh -c
        replaceinfile "Categories=Application;" "Categories=System;" /usr/share/applications/RAIDar-0.desktop
    fi
fi    

# Zimbra
if [ ${INSTALL_ZIMBRA_DESKTOP} -eq 1 ]; then
    packer_install "zdesktop"
fi    

ncecho " [x] Removing 'wine' file associations "
rm /home/${SUDO_USER}/.local/share/applications/wine-extension-*.desktop >>"$log" 2>&1
cecho success

ncecho " [x] Purging 'packer' builds "
rm -rfv /tmp/packerbuild-* >>"$log" 2>&1 &
pid=$!;progress $pid

ncecho " [x] Updating font cache "
fc-cache -f -v >>"$log" 2>&1 &
pid=$!;progress $pid
