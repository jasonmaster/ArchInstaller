ArchInstaller is a simply suite a bash scripts to automate the installation of
Arch Linux.

  * `arch-installer.sh` should be run from the [Arch Linux install ISO](https://www.archlinux.org/download/).
  * `gnome-desktop.sh` should be run from a Arch Linux system that was installed using `arch-installer`.

# Install Arch Linux

Boot the install ISO and clone this repository.

    loadkeys uk
    wifi-menu
    dhcpcd    
    pacman -Syy
    pacman -S git
    git clone https://github.com/flexiondotorg/ArchInstaller.git
    cd ArchInstaller
    
Edit the `users.csv` files to suite your requirements. Run the installer script,
for example.

    ./arch-installer.sh -d sda -p bsrh -w pA55w0rd -n myhost.example.org
    
You can get help with the following.

    ./arch-instaler.sh -h
    
The `arch-installer.sh` will install a base system with some essential tools. It
doesn't install X11 or any desktop environment.

# Install GNOME

Once the system has been installed using `arch-installer.sh` clone this repository
again and run:

    ./gnome-desktop.sh
    
Currently, there are no command line switched to control how `gnome-desktop.sh`
operates, but you can edit the script and toogle the following.

    INSTALL_BROWSERS=0
    INSTALL_LIBREOFFICE=1
    INSTALL_DEVELOPMENT=1
    INSTALL_GOOGLE_EARTH=1
    INSTALL_VIRTUALBOX=0
    INSTALL_CHAT_APPS=1
    INSTALL_GRAPHIC_APPS=1
    INSTALL_3D_APPS=0
    INSTALL_PHOTO_APPS=1
    INSTALL_MUSIC_APPS=1
    INSTALL_VIDEO_PLAYER_APPS=1
    INSTALL_VIDEO_EDITOR_APPS=0
    INSTALL_VIDEO_RIPPER_APPS=0
    INSTALL_REMOTE_DESTOP_APPS=1
    INSTALL_DOWNLOAD_APPS=1
    INSTALL_ZIMBRA_DESKTOP=0
    INSTALL_IPMIVIEW=0
    INSTALL_RAIDAR=0
    INSTALL_WINE=1
    INSTALL_CRYPTO_APPS=1
    INSTALL_BACKUP_APPS=0

# Limitations

  * These scripts are heavily biased toward my own preferences and may not suit your needs.
  * These scripts are not well tested. I've published them here for some of the guys at work to experiment with.
