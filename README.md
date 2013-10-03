# Introduction

ArchInstaller is a `bash` script to automate the installation and initial
configuration of [Arch Linux](http://www.archlinux.org). `arch-install.sh`
should be run from the [Arch Linux install ISO](https://www.archlinux.org/download/).

## Features

  * It works for me.
  * Automated installation of base Arch Linux.
  * Extensive filesystem support. Auto detects and configure SSDs and TRIM:
    * bfs
    * btrfs
    * ext{2,3,4}
    * f2fs
    * jfs
    * nilfs2
    * ntfs
    * reiserfs
    * xfs
  * Works on PCs (x86 and x86_64) and Raspberry Pi (no filesystem options on the Pi).
  * On x86_64 desktops the `multi-lib` repository is automatically enabled and `multilib-devel` automatically installed.
  * Automated installation of your preferred desktop environment, or none at all.
    * Cinnamon
    * GNOME
    * Hawaii (untested)
    * KDE
    * LXDE
    * MATE
    * XFCE
  * Automated hardware detection and driver installation. See below.  
  * Installations can be sped up via the use of an NFS cache. See below.
  * Optional "minimal" installation is available which just install the base OS.
  * Power management *"out of the box"*.
  * Adheres to the Arch principle of K.I.S.S.

## Limitations

  * Heavily biased toward my own preferences and may not suit your needs.
  * Does not support UEFI. I don't have any UEFI hardware to test on.
  * Only simple partition recipes are available.

# Install Arch Linux

Boot the [Arch Linux install ISO](https://www.archlinux.org/download/) and clone
ArchInstaller.

    loadkeys uk
    wifi-menu
    dhcpcd
    pacman -Syy --noconfirm git
    git clone https://github.com/flexiondotorg/ArchInstaller.git
    cd ArchInstaller

Edit the `users.csv` file to suite your requirements, see `users.example` for
reference. Run the install script, for example.

## PC

    ./arch-install.sh -d sda -p bsrh -w pA55w0rd -n myhost.example.org

## Raspberry Pi

The Raspberry Pi mode doesn't do any disk partitioning so the partition options
are redundant on the Pi.

    ./arch-install.sh -w pA55w0rd -n myhost.example.org

You can get help with the following.

    ./arch-install.sh -h

## Hardware Detection

`arch-install.sh` will probe the PCI and USB bus for vendor and device codes and
then automatically execute the corresponding scripts in `hardware/{pci,usb}`.

`arch-install.sh` will also use `dmidecode` to probe your computer for the fields
below and automatically execute the corresponding scripts in `hardware/system`.

  * Product Name
  * Version
  * Serial Number
  * UUID
  * SKU Number
  
The facilities to customise the install any given hardware requirements, right
down to a specific tweak for a unique computer. See the scripts I've already
created, they are good references to get you started.

## NFS Cache

`arch-install.sh` can use an existing `pacman` cache on an existing host to
speed up the installation time. If you already have a host running Arch Linux
this is how you can share your `pacman` cache via NFS.

    sudo pacman -S nfs-utils

Add the following to `/etc/exports`.

    /var/cache/pacman/pkg   *(rw,no_root_squash)

To start the NFS server, use:

    systemctl start rpc-idmapd.service rpc-mountd.service

To start NFS automatically on every boot, use:

    systemctl enable rpc-idmapd.service rpc-mountd.service

When you execute `arch-install.sh` pass in the `-c` argument, for example:

    ./arch-install.sh -d sda -p bsrh -w pA55w0rd -n myhost.example.org -c myexistinghost:/var/cache/pacman/pkg

If you provide `arch-install.sh` an NFS cache it will add that cache to `/etc/fstab`
on the installed system.

## Power Management

Power management is fairly complete right now, although SATA ALPM is disabled
due to the risk of data corruption.

    * <https://bugs.launchpad.net/ubuntu/+source/linux/+bug/539467>
    * <https://wiki.ubuntu.com/Kernel/PowerManagementALPM>

I've opted to use [cpupower](https://wiki.archlinux.org/index.php/CPU_Frequency_Scaling)
and [TLP](http://linrunner.de/en/tlp/tlp.html) for CPU frequency and power management. 

The following are useful sources of reference.

  * <http://kernel.ubuntu.com/~cking/power-benchmarking/>
  * <http://crunchbang.org/forums/viewtopic.php?id=11954>
  * <http://crunchbang.org/forums/viewtopic.php?id=23456>
  * <https://bbs.archlinux.org/viewtopic.php?id=134109>
  * <http://www.thinkwiki.org/wiki/How_to_reduce_power_consumption>
  * <http://linrunner.de/en/tlp/docs/tlp-faq.html>

## FONT and FONT_MAP

Read the following to understand how to tweak the `FONT` and `FONT_MAP`
settings in `arch-install.sh`.

  * <https://wiki.archlinux.org/index.php/Fonts#Console_fonts>
  * <http://en.wikipedia.org/wiki/ISO/IEC_8859>
  * <http://alexandre.deverteuil.net/consolefonts/consolefonts.html>

## TODO

  * Add automated root partition resizing magic to `arch-install.sh` for Raspberry Pi.
    * <http://michael.otacoo.com/manuals/raspberry-pi/>
  * Detect locale for dictionaries in desktop environment installs.
  * When the script changes something in a user home directory, make that change for all users.
  * Fix Thinkpad T43p hotkeys keys.
    * Run one of the following on system start up.
    * `echo enable,0x00ffffff > /proc/acpi/ibm/hotkey`
    * `cp /sys/devices/platform/thinkpad_acpi/hotkey_all_mask /sys/devices/platform/thinkpad_acpi/hotkey_mask`
    * <http://www.thinkwiki.org/wiki/Thinkpad-acpi>
    * <https://github.com/torvalds/linux/blob/master/Documentation/laptops/thinkpad-acpi.txt>
    * <http://ubuntuforums.org/showthread.php?t=1328016>
    * <https://bbs.archlinux.org/viewtopic.php?id=147160>
  * Review the links below, see if there is anything I can re-use.
    * <https://github.com/helmuthdu/aui>
    * <https://github.com/Antergos/Cnchi>
    * <http://www.winpe.com/page04.html>
    * <http://blog.burntsushi.net/lenovo-thinkpad-t430-archlinux>
    * <http://worldofgnome.org/speed-up-gnome-in-systemd-distributions/>
  * UEFI support - waiting for UEFI support in SYSLINUX.
  * Maybe allow locating `/home` on a different disk.
  * Maybe add LVM and LUKS capability to disk partitioning.
  * Investigate zRAM and zSWAP.

### Power Management TODO

The following still needs attention.

  * Suspend hook for `/dev/mmcblk0`

### Video drivers TODO 

  * Unichrome or OpenChrome?
    * <https://wiki.archlinux.org/index.php/Via_Unichrome>
    * <https://bbs.archlinux.org/viewtopic.php?pid=1104036>
    * <https://bbs.archlinux.org/viewtopic.php?pid=1201986>
    * <http://www.openchrome.org/>
    * <http://unichrome.sourceforge.net/>
