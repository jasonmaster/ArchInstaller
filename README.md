ArchInstaller is a simply suite a bash scripts to automate the installation of
Arch Linux.

  * `arch-installer.sh` should be run from the [Arch Linux install ISO](https://www.archlinux.org/download/).
  * `gnome-desktop.sh` should be run from a Arch Linux system that was installed using `arch-installer`.

# Install Arch Linux

Boot the install ISO and clone this repository.

    loadkeys uk
    wifi-menu
    dhcpcd
    pacman -Syy git
    git clone https://github.com/flexiondotorg/ArchInstaller.git
    cd ArchInstaller

Edit the `users.csv` file to suite your requirements. Run the installer script,
for example.

    ./arch-installer.sh -d sda -p bsrh -w pA55w0rd -n myhost.example.org

You can get help with the following.

    ./arch-instaler.sh -h

The `arch-installer.sh` will install a base system with some essential tools. It
doesn't install X11 or any desktop environment.

## FONT and FONT_MAP

Read the following to understand how to tweak the `FONT` and `FONT_MAP`
settings in `arch-installer.sh`.

  * <https://wiki.archlinux.org/index.php/Fonts#Console_fonts>
  * <http://en.wikipedia.org/wiki/ISO/IEC_8859>
  * <http://alexandre.deverteuil.net/consolefonts/consolefonts.html>

## NFS Cache

`arch-installer.sh` can use an existing `pacman` cache on an existing host to
speed up the installation time. If you already have a host running Arch Linux
this is how you can share your `pacman` cache via NFS.

    sudo pacman -S nfs-utils

Add the following to `/etc/exports`.

    /var/cache/pacman/pkg   *(rw,no_root_squash)

To start the NFS server, use:

    systemctl start rpc-idmapd.service rpc-mountd.service

To start NFS automatically on every boot, use:

    systemctl enable rpc-idmapd.service rpc-mountd.service

When you execute `arch-installer.sh` pass in the `-c` argument, for example:

    ./arch-installer.sh -d sda -p bsrh -w pA55w0rd -n myhost.example.org -c myexistinghost:/var/cache/pacman/pkg

# Install GNOME

Once the system has been installed using `arch-installer.sh` clone this repository
again and run:

    ./gnome-desktop.sh

There are no command line switches to control how `gnome-desktop.sh` operates,
but you can edit the script and toogle the following.

    INSTALL_BROWSERS=0
    INSTALL_LIBREOFFICE=0
    INSTALL_GENERAL_DEVELOPMENT=0
    INSTALL_ANDROID_DEVELOPMENT=0
    INSTALL_GOOGLE_EARTH=0
    INSTALL_VIRTUALBOX=0
    INSTALL_CHAT_APPS=0
    INSTALL_GRAPHIC_APPS=0
    INSTALL_3D_APPS=0
    INSTALL_PHOTO_APPS=0
    INSTALL_MUSIC_APPS=0
    INSTALL_VIDEO_PLAYER_APPS=0
    INSTALL_VIDEO_EDITOR_APPS=0
    INSTALL_VIDEO_RIPPER_APPS=0
    INSTALL_REMOTE_DESKTOP_APPS=0
    INSTALL_DOWNLOAD_APPS=0
    INSTALL_ZIMBRA_DESKTOP=0
    INSTALL_IPMIVIEW=0
    INSTALL_RAIDAR=0
    INSTALL_WINE=0
    INSTALL_CRYPTO_APPS=0
    INSTALL_BACKUP_APPS=0

`gnome-desktop.sh` can be run multiple times. It will not re-install anything
that is already present, so subsequent runs are quicker.

# Limitations

  * These scripts are heavily biased toward my own preferences and may not suit your needs.
  * These scripts are not well tested. I've published them here for some of the guys at work to experiment with.

# TODO

  * Refactor graphics cards detection using `/sys/kernel/debug/dri/0/name`.
    * Fall back to `lspci` for VirtualBox.
  * Unify changes to users home directory for all users.
  * Fix suspend on the Thinkpad.
    * Should `acpid` be used as well?
  * Detect locale for dictionaries in `gnome-desktop.sh`.
  * Refactor `arch-installer.sh` to use `common.sh`.
  * Add installation profiles to `gnome-desktop.sh`.
  * Maybe add "do nothing" option for partitioning and filesystem creation.
  * Review CPU detection. Just detect what the current kernel is running.
  * Maybe create an LVM and lob everything in it except for `/boot`?
  * Consolidate the partitioning.
  * Detect SSD and TRIM and add `discard` to `/etc/fstab`.
    * `/sys/block/sdX/queue/rotational` # 0 = SSD
    * `/sys/block/sda/removable` # 0 = not removable
    * `sudo hdparm -I /dev/sda | grep "TRIM supported"`
  * Review the links below, see if there is anything I can re-use.
    * <https://github.com/helmuthdu/aui>
    * <http://www.winpe.com/page04.html>
    * <http://blog.burntsushi.net/lenovo-thinkpad-t430-archlinux>
  * UEFI boot - I don't have any UEFI systems to test.
    * Wait for UEFI dupport in SYSLINUX.
  * Investigate zRAM and zSWAP.

## Power Management

At some point I want these scripts to provision an Arch Linux system with a
ready to run power management configuration.

The following are useful sources of reference.

  * <http://kernel.ubuntu.com/~cking/power-benchmarking/>
  * <http://crunchbang.org/forums/viewtopic.php?id=11954>
  * <http://crunchbang.org/forums/viewtopic.php?id=23456>
  * <https://bbs.archlinux.org/viewtopic.php?id=134109>
  * <http://www.thinkwiki.org/wiki/How_to_reduce_power_consumption>
  * <http://linrunner.de/en/tlp/docs/tlp-faq.html>

I've opted to use TLP for power management as it provides a comprehensive
collection of power management scripts. pm-utils is still being used for
suspend/hibernate and resume functions, but its `power.d` scripts are disabled
by `gnome-desktop.sh`.

### Power Management TODO

Power management is fairly complete right now, but the following still needs
attention.

  * Suspend hook for `/dev/mmcblk0`
  * SATA ALPM is disabled by `gnome-desktop.sh` due to the risk of data corruption.
    * https://bugs.launchpad.net/ubuntu/+source/linux/+bug/539467
    * https://wiki.ubuntu.com/Kernel/PowerManagementALPM
  * Active State Power Management - fixed since kernel 3.4.
    * Still requires the `pcie_aspm=force` kernel option is set.
    * https://bbs.archlinux.org/viewtopic.php?id=120640
    * http://smackerelofopinion.blogspot.co.uk/2011/03/making-sense-of-pcie-aspm.html
    * http://crunchbang.org/forums/viewtopic.php?id=23445
    * I've submitted a pull request to `laptop-mode-tools`.
      * <https://github.com/rickysarraf/laptop-mode-tools/pull/7>
    * TLP has this capability.
  * Intel i915 power management, see below.
  * Nouveau power management, see below.
  * Blacklist or unload `pcmcia` and `yenta_socket` kernel modules.
  * Blacklist or unload `parport`, `ppdev` kernel modules.
  * Experiment with PHC
    * <https://wiki.archlinux.org/index.php/PHC>

#### Radeon

Power management implemented via TLP.

  * <http://www.x.org/wiki/RadeonFeature#KMS_Power_Management_Options>
  * <https://wiki.archlinux.org/index.php/ATI#Powersaving>
  * <http://www.overclock.net/t/731469/how-to-power-saving-with-the-radeon-driver>

I still need to detect AGP radeon cards and add the kernel options to
`/etc/modprobe.d/radeon.conf`.

    radeon.agpmode=x
    radeon.gartsize=yy

Where x is:

  * -1 = Enable PCI mode on the GPU disable all AGP.
  * 1, 2, 4, 8 = Enable AGP speed.

And yy is the GART size.

Also create a sensible `/etc/X11/xorg.conf.d/20-radeon.conf`. Options for consideration:

    Section "Device"
        Identifier  "My Graphics Card"
        Option  "AccelMethod"           "glamor" # default is EXA
        Option  "AGPMode"               "8"   #not used when KMS is on
        Option  "AGPFastWrite"          "off" #could cause instabilities enable it at your own risk
        Option  "RenderAccel"           "on"  #enabled by default on all radeon hardware
        Option  "EXAVSync"              "off" #default is off, otherwise on
        Option  "EXAPixmaps"            "on"  #when on icreases 2D performance, but may also cause artifacts on some old cards
        Option  "AccelDFS"              "on"  #default is off, read the radeon manpage for more information
    EndSection

Enable Hyper-Z. For the pre-R500 hardware, the support can be easily enabled
at this time through setting the `RADEON_HYPERZ` environment variable.

#### Nouveau

Not done yet.

  * <http://nouveau.freedesktop.org/wiki/PowerManagement>
  * <http://ubuntuforums.org/showthread.php?t=1718929>
  * <http://www.phoronix.com/scan.php?page=article&item=nouveau_reclocking_one&num=1>

#### Intel

Power management implemented via TLP, although I'm not sure the implementation
is correct. I will add the kernel options to `/etc/modprobe.d`.

  * <http://www.kubuntuforums.net/showthread.php?57279-How-to-Enable-power-management-features>
  * <http://www.phoronix.com/scan.php?page=article&item=intel_i915_power&num=1>
  * <http://www.scribd.com/doc/73071712/Intel-Linux-Graphics>

    i915.i915_enable_rc6=1 i915.i915_enable_fbc=1 i915.lvds_downclock=1 i915.semaphores=1

Use this to detect i915 capable cards?

    cat /sys/kernel/debug/dri/0/i915_capabilities

### Alternatives

### TLP

[TLP](http://linrunner.de/en/tlp/tlp.html) is a suitable alternaive to
laptop-mode-tools and it now installed by `gnome-installer.sh`. It has the
same features as laptop-mode-tools with the following differences:

  * Includes device specific support for Thinkpads.
  * Include support for PCIe ASPM.
  * Includes support for Radeon power profiles.
  * Includes support for Intel `i915` power management. Although I'm not sure the implementation is entirely correct.
  * Missing LCD brightness controls.

Find out more here.

  * <https://github.com/linrunner/TLP>
  * <https://wiki.archlinux.org/index.php/TLP>
  * <https://aur.archlinux.org/packages.php?ID=48464>

My tests demonstrated that TLP resulted in lower power consumption on a
Thinkpad T43p running on battery when compared to laptop-mode-tools.

#### Powerdown

[Powerdown](https://github.com/taylorchu/powerdown) could be a viable
alternative to laptop-mode-tools, but it entirely replaces pm-utils when
installed from the AUR. pm-utils which is required by GNOME and Powerdown
doesn't have the depth of support for suspend/resume operations that pm-utils
does. Still interesting though.

Find out more here.

  * <https://github.com/taylorchu/powerdown>
  * <https://wiki.archlinux.org/index.php/Powerdown>
  * <https://aur.archlinux.org/packages/powerdown/>

#### sysconf

Find out more here.

  * [sysconf](https://bbs.archlinux.org/viewtopic.php?id=144507)
