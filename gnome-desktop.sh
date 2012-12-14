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
INSTALL_LIBREOFFICE=0
INSTALL_GENERAL_DEVELOPMENT=0
INSTALL_ANDROID_DEVELOPMENT=0
INSTALL_GOOGLE_EARTH=0
INSTALL_VIRTUALBOX=0
INSTALL_BOXES=0
INSTALL_CHAT_APPS=0
INSTALL_GRAPHIC_APPS=0
INSTALL_3D_APPS=0
INSTALL_PHOTO_APPS=0
INSTALL_MUSIC_APPS=0
INSTALL_VIDEO_PLAYER_APPS=0
INSTALL_VIDEO_EDITOR_APPS=0
INSTALL_VIDEO_RIPPER_APPS=0
INSTALL_REMOTE_DESKTOP_APPS=0
INSTALL_NETWORK_APPS=0
INSTALL_DOWNLOAD_APPS=0
INSTALL_ZIMBRA_DESKTOP=0
INSTALL_IPMIVIEW=0
INSTALL_RAIDAR=0
INSTALL_WINE=0
INSTALL_CRYPTO_APPS=0
INSTALL_BACKUP_APPS=0

# Upgrade currently installed packages
# - Hmm, it might not make sense to do this here. Package upgrades may require
#   user input.
#pacman_upgrade
#packer_upgrade

# Make sure all the required packages are installed.
pacman_install "`cat extra-packages.txt`"
HAS_PACKER=`which packer 2>/dev/null`
if [ $? -ne 0 ] && [ -x ./packer-installer.sh ]; then
    ./packer-installer.sh
fi

# I make mistakes and bad choices. This corrects them.
if [ -x ./errata.sh ]; then
    ./errata.sh
fi

# Power Saving
laptop-detect
if [ $? -eq 0 ]; then
    packer_install "tlp"
    # Some SATA chipsets can corrupt data when ALPM is enabled. Disable it
    replaceinfile 'SATA_LINKPWR' '#SATA_LINKPWR' /etc/default/tlp
    replaceinfile "PCIE_ASPM_ON_AC=performance" "PCIE_ASPM_ON_AC=default" /etc/default/tlp
    replaceinfile "BAY_POWEROFF_ON_BAT=0" "BAY_POWEROFF_ON_BAT=1" /etc/default/tlp

    # Enable brightness control.
    cat >/etc/pm/power.d/display-brightness<<'ENDBRIGHTNESS'
#!/usr/bin/env bash

BRIGHTNESS=""
MAX_BRIGHTNESS=""
if [ -w /proc/acpi/ibm/brightness ]; then
    BRIGHTNESS="/proc/acpi/ibm/brightness"
    MAX_BRIGHTNESS="/proc/acpi/ibm/max_brightness"
elif [ -w /sys/class/backlight/acpi_video0/ ]; then
    BRIGHTNESS="/sys/class/backlight/acpi_video0/brightness"
    MAX_BRIGHTNESS="/sys/class/backlight/acpi_video0/max_brightness"
fi

if [ -n "${BRIGHTNESS}" ]; then
    case $1 in
        true)
            echo "Enable screen power saving : ${BRIGHTNESS}"
            echo 0 > ${BRIGHTNESS}
            ;;
        false)
            echo "Disable screen power saving : ${BRIGHTNESS}"
            cat ${MAX_BRIGHTNESS} > ${BRIGHTNESS}
            ;;
    esac
fi
ENDBRIGHTNESS

    chmod +x /etc/pm/power.d/display-brightness
    system_ctl enable tlp-init
fi

# Install video driver (DRI)
if [ -n "${VIDEO_DRI}" ]; then
    pacman_install "${VIDEO_DRI}"
    if [ "${CPU}" == "x86_64" ]; then
        pacman_install "lib32-${VIDEO_DRI}"
    fi
fi

# Xorg
pacman_install_group "xorg"
pacman_install_group "xorg-apps"

# Install video drivers (DDX)
pacman_install "${VIDEO_DDX}"

# Video decoder acceleration (VDPAU, libVA, etc)
if [ -n "${VIDEO_DECODER}" ]; then
    pacman_install "${VIDEO_DECODER}"
fi

# Configure init things
update_early_modules ${VIDEO_KMS}

# Configure kernel module options
if [ -n "${VIDEO_MODPROBE}" ] && [ -n "${VIDEO_KMS}" ]; then
    echo "${VIDEO_MODPROBE}" > /etc/modprobe.d/${VIDEO_KMS}.conf
fi

# Touch Screen
# - http://www.x.org/archive/X11R7.5/doc/man/man4/evdev.4.html
# - https://bbs.archlinux.org/viewtopic.php?id=126208
# Is there an eGalax touch screen available?
TOUCH_SCREEN=0
EGALAX=`lsusb | grep -q 0eef:0001`
if [ $? -eq 0 ]; then
    TOUCH_SCREEN=1
    echo " [!] eGalax touch screen detected"
    if [ ! -f /etc/modprobe.d/blacklist-usbtouchscreen.conf ]; then
        packer_install "xinput_calibrator"
        rmmod usbtouchscreen 2>/dev/null

        cat >/etc/modprobe.d/blacklist-usbtouchscreen.conf<<ENDEGALAX
# Do not load the 'usbtouchscreen' module, as it conflicts with eGalax
blacklist usbtouchscreen
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

# Thinkpad T43
#  - https://communities.bmc.com/communities/blogs/linux/2010/03/16/ubuntu-1004-and-the-t43
#  - http://pc-freak.net/blog/controlling-fan-with-thinkfan-on-lenovo-thinkpad-r61-on-debian-gnulinux-adjusting-proper-fan-cycling/
T43=`dmidecode --type 1 | grep "ThinkPad T43"`
if [ $? -eq 0 ]; then
    pacman_install "fprintd tp_smapi"
    packer_install "thinkfan"
    echo "options thinkpad_acpi fan_control=1" > /etc/modprobe.d/thinkpad_acpi.conf
    cp /usr/share/doc/thinkfan/examples/thinkfan.conf.thinkpad /etc/thinkfan.conf
    system_ctl --system daemon-reload
    system_ctl enable thinkfan
    #TODO - hsfmodem hdaps
fi

VIRTUALBOX_GUEST=`dmidecode --type 1 | grep VirtualBox`
if [ $? -eq 0 ]; then
    pacman_install "virtualbox-guest-utils"
    echo "vboxguest" >  /etc/modules-load.d/virtualbox-guest.conf
    echo "vboxsf"    >> /etc/modules-load.d/virtualbox-guest.conf
    echo "vboxvideo" >> /etc/modules-load.d/virtualbox-guest.conf
    modprobe -a vboxguest vboxsf vboxvideo

    # Enable access to Shared Folders
    #groupadd vboxsf
    add_user_to_group ${SUDO_USER} vboxsf

    # Synchronise date/time to the host
    system_ctl stop ntpd.service
    system_ctl disable ntpd.service
    system_ctl enable vboxservice
    system_ctl start vboxservice
fi

# Fonts
pacman_install "ttf-bitstream-vera ttf-liberation ttf-ubuntu-font-family"
packer_install "ttf-fixedsys-excelsior-linux ttf-ms-fonts ttf-source-code-pro"

# Gnome
pacman_install_group "gnome"
pacman_install_group "gnome-extra"
pacman_install_group "telepathy"
pacman_install "epiphany-extensions gedit-plugins gnome-tweak-tool networkmanager-pptp"
packer_install "firewalld gnome-packagekit gnome-settings-daemon-updates polkit-gnome terminator"
# Gstreamer
pacman_install "gst-plugins-base gst-plugins-base-libs gst-plugins-good \
gst-plugins-bad gst-plugins-ugly gst-ffmpeg" "GStreamer"
if [ ${TOUCH_SCREEN} -eq 1 ]; then
    pacman_install "xournal"
fi

# Gnome Display Manager
system_ctl enable gdm.service
# D-Bus interface for user account query and manipulation
system_ctl enable accounts-daemon.service
# Enumerates power devices, listens to device events and querys history and statistics
system_ctl enable upower.service
# Network Manager
system_ctl enable NetworkManager.service
# FirewallD
system_ctl enable firewalld.service

# Printing
pacman_install "cups foomatic-db foomatic-db-engine foomatic-db-nonfree \
foomatic-filters gutenprint"
system_ctl enable cups.service

# Dropbox
packer_install "dropbox dropbox-dark-panel-icons"

# Flash & Java
pacman_install "nspluginwrapper flashplugin"
if [ "${CPU}" == "x86_64" ]; then
    packer_install "lib32-flashplugin"
fi
#packer_install "jre6"

ncecho " [x] Configuring plugins "
nspluginwrapper -v -n -a -i >>"$log" 2>&1 &
pid=$!;progress $pid

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
    pacman_install "glabels"
fi

# Development
if [ ${INSTALL_GENERAL_DEVELOPMENT} -eq 1 ]; then
    pacman_install "python-pip python-distribute python-virtualenv"
    pacman_install "python2-pip python2-distribute python2-virtualenv \
    python-virtualenvwrapper"

    pacman_install "meld poedit pygtksourceview2"
    packer_install "bzr-fastimport kiki-re retext sqlite-manager winpdb wxhexeditor"
    packer_install "upslug2"

    # Gedit
    packer_install "gedit-advancedfind"
    packer_install "gedit-smart-highlighting-plugin"
    chmod 666 /usr/lib/gedit/plugins/smart_highlight/config.xml
    packer_install "gedit-source-code-browser gedit-django-project gdp"

    # Mine
    packer_install "gedit-schemer-plugin gedit-imitation-plugin gedit-open-uri-context-menu-plugin"

    pacman_install "pgadmin3"
    packer_install "wingide"
fi

if [ ${INSTALL_ANDROID_DEVELOPMENT} -eq 1 ]; then
    packer_install "jdk6 android-sdk-platform-tools"
fi

# Google Earth
if [ ${INSTALL_GOOGLE_EARTH} -eq 1 ]; then
    packer_install "ld-lsb"
    packer_install "google-earth"
    # TODO - Remove this work around when bugs in current version are fixed.
    if [ -f /etc/fonts/conf.d/65-fonts-persian.conf ]; then
        mv /etc/fonts/conf.d/65-fonts-persian.conf /etc/fonts/conf.d/65-fonts-persian.conf.breaks-google-earth
    fi
fi

# Make sure we are not a VirtualBox Guest
VIRTUALBOX_GUEST=`dmidecode --type 1 | grep VirtualBox`
if [ $? -eq 1 ]; then
    # Virtualbox
    if [ ${INSTALL_VIRTUALBOX} -eq 1 ]; then
        pacman_install "virtualbox virtualbox-host-modules virtualbox-guest-iso"
        packer_install "virtualbox-ext-oracle"
        # FIXME - do this for all users
        add_user_to_group ${SUDO_USER} vboxusers
        echo "vboxdrv"    >  /etc/modules-load.d/virtualbox-host.conf
        echo "vboxnetadp" >> /etc/modules-load.d/virtualbox-host.conf
        echo "vboxnetflt" >> /etc/modules-load.d/virtualbox-host.conf
        modprobe -a vboxdrv vboxnetadp vboxnetflt
    fi
    if [ ${INSTALL_BOXES} -eq 1 ]; then
        packer_install "gnome-boxes"
    fi
else
    cecho " [!] VirtualBox was not installed as we are a VirtualBox guest."
    sleep 2
fi

# Chat
if [ ${INSTALL_CHAT_APPS} -eq 1 ]; then
    # TODO - Skype notifications
    pacman_install "skype xchat"
fi

# Graphics
if [ ${INSTALL_GRAPHIC_APPS} -eq 1 ]; then
    pacman_install "gcolor2 gimp simple-scan"
fi

# 3D Graphics
if [ ${INSTALL_3D_APPS} -eq 1 ]; then
    packer_install "sweethome3d"
fi

# Photo Managers
if [ ${INSTALL_PHOTO_APPS} -eq 1 ]; then
    pacman_install "shotwell"
fi

# Music
if [ ${INSTALL_MUSIC_APPS} -eq 1 ]; then
    pacman_install "banshee mp3gain"
    pacman_install "picard chromaprint libdiscid"
    packer_install "picard-plugins google-musicmanager nuvolaplayer"

    # TODO
    #  - Do this for all users
    # Use the 'standard' preset by default. This preset should generally be
    # transparent to most people on most music and is already quite high in quality.
    # The resulting bitrate should be in the 170-210kbps range, according to music
    # complexity.
    sudo -u ${SUDO_USER} gconftool-2 --type string --set /system/gstreamer/0.10/audio/profiles/mp3/pipeline "audio/x-raw-int,rate=44100,channels=2 ! lame name=enc preset=1001 ! id3v2mux"    
fi

# Video
if [ ${INSTALL_VIDEO_PLAYER_APPS} -eq 1 ]; then
    # DVD & Blu-Ray
    pacman_install "libbluray libdvdread libdvdcss libdvdnav vlc"
    packer_install "libaacs"
    # TODO - do this for all users
    wget_install_generic "http://vlc-bluray.whoknowsmy.name/files/KEYDB.cfg" "/home/${SUDO_USER}/.config/aacs/"
    chown -R ${SUDO_USER}:users /home/${SUDO_USER}/.config

    addlinetofile "[archnetflix]" /etc/pacman.conf
    addlinetofile "SigLevel = Required DatabaseOptional TrustedOnly" /etc/pacman.conf
    addlinetofile 'Server = http://demizerone.com/$repo/$arch' /etc/pacman.conf

    # TODO - move to common.sh
    ncecho " [x] Getting key 0EE7A126 "
    pacman-key --recv-keys 0EE7A126 >>"$log" 2>&1 &
    pid=$!;progress $pid

    # TODO - move to common.sh
    ncecho " [x] Signing key 0EE7A126 "
    pacman-key --lsign-key 0EE7A126 >>"$log" 2>&1 &
    pid=$!;progress $pid

    ncecho " [x] Syncing (arch) "
    pacman -Syy >>"$log" 2>&1 &
    pid=$!;progress $pid
    pacman_install "netflix-desktop"
fi

if [ ${INSTALL_VIDEO_RIPPER_APPS} -eq 1 ]; then
    pacman_install "handbrake mediainfo mkvtoolnix-cli mkvtoolnix-gtk"
    packer_install "get_iplayer makemkv tsmuxer-gui"
fi

if [ ${INSTALL_VIDEO_EDITOR_APPS} -eq 1 ]; then
    pacman_install "devede openshot"
    packer_install "arista-transcoder ttcut-svn"
    # TODO - Maybe project-x gopchop
fi

# Remote Desktop
if [ ${INSTALL_REMOTE_DESKTOP_APPS} -eq 1 ]; then
    #pacman_install "remmina freerdp nxproxy" # vinagre does what I need for now
    pacman_install "nxclient rdesktop tigervnc"
fi

# Network Tools
if [ ${INSTALL_NETWORK_APPS} -eq 1 ]; then
    packer_install "gip"
fi

# Download Managers
if [ ${INSTALL_DOWNLOAD_APPS} -eq 1 ]; then
    pacman_install "clamz filezilla ncftp nfoview terminus-font transmission-gtk tucan"

    # TODO - do this for all users
    # Update transmission config
    if [ -f /home/${SUDO_USER}/.config/transmission/settings.json ]; then
        replaceinfile '"blocklist-enabled": false' '"blocklist-enabled": true' /home/${SUDO_USER}/.config/transmission/settings.json
        replaceinfile "www\.example\.com\/blocklist" "list\.iblocklist\.com\/\?list=bt_level1&fileformat=p2p&archiveformat=gz" /home/${SUDO_USER}/.config/transmission/settings.json
    fi

    packer_install "pymazon"
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

# Crypto
if [ ${INSTALL_CRYPTO_APPS} -eq 1 ]; then
    pacman_install "truecrypt"
    packer_install "pocket"
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

ncecho " [x] Updating font cache "
fc-cache -f -v >>"$log" 2>&1 &
pid=$!;progress $pid
