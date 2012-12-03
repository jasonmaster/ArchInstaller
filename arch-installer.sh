#!/usr/bin/env bash

#TODO
# - Add an option for pacstrap to use a local package cache.
# - Maybe create an LVM and lob everything in it except for `/boot`.
# - Consolidate the partitioning.
# - Detect SSD and TRIM and add `discard` to `/etc/fstab`.
#   /sys/block/sdX/queue/rotational # 0 = SSD
#   /sys/block/sda/removable # 0 = not removable
#   sudo hdparm -I /dev/sda | grep "TRIM supported"
#   Use noatime
# - Some good stuff below, check it out
#   https://github.com/helmuthdu/aui
#   https://github.com/helmuthdu/dotfiles
#   http://www.winpe.com/page04.html
# - Get a handle on power management
#   suspend hook for /dev/mmcblk0
#     - ATI http://www.x.org/wiki/RadeonFeature#KMS_Power_Management_Options
#           https://wiki.archlinux.org/index.php/ATI#Powersaving
#           http://www.overclock.net/t/731469/how-to-power-saving-with-the-radeon-driver
#           Battery
#           #!/bin/sh
#           echo profile > /sys/class/drm/card0/device/power_method
#           echo mid > /sys/class/drm/card0/device/power_profile
#           Power
#           #!/bin/sh
#           echo profile > /sys/class/drm/card0/device/power_method
#           echo auto > /sys/class/drm/card0/device/power_profile
#     - Nouveau http://nouveau.freedesktop.org/wiki/PowerManagement
#     -         http://ubuntuforums.org/showthread.php?t=1718929
#     -         http://www.phoronix.com/scan.php?page=article&item=nouveau_reclocking_one&num=1
#     - Intel
#     -         http://www.kubuntuforums.net/showthread.php?57279-How-to-Enable-power-management-features
#     -         http://www.phoronix.com/scan.php?page=article&item=intel_i915_power&num=1
#   http://blog.burntsushi.net/lenovo-thinkpad-t430-archlinux
# - UEFI boot.
#   I have no UEFI systems to test this.

BASE_GROUPS="adm,audio,disk,lp,optical,storage,video,games,power,scanner"
DSK=""
NFS_CACHE=""
FQDN="arch.example.org"
TIMEZONE="Europe/London"
KEYMAP="uk"
LANG="en_GB.UTF-8"
LC_COLLATE="C"
FONT="alt-8x14"
FONTMAP="8859-14_to_uni"
PASSWORD=""
FS="ext4" #or xfs are the only supported options right now.
PARTITION_TYPE="msdos"
PARTITION_LAYOUT=""
MINIMAL=0

function usage() {
    echo
    echo "Usage"
    echo "  ${0} -d sda -p bsrh -w P@ssw0rd -b ${PARTITION_TYPE} -f ${FS} -k ${KEYMAP} -l ${LANG} -n ${FQDN} -t ${TIMEZONE}"
    echo
    echo "Required parameters"
    echo "  -d : The target device. For example, 'sda'."
    echo "  -p : The partition layout to use. One of: "
    echo "         'bsrh' : /boot, swap, /root and /home"
    echo "         'bsr'  : /boot, swap and /root"
    echo "         'br'   : /boot and /root, no swap."
    echo "  -w : The root password."
    echo
    echo "Optional parameters"
    echo "  -b : The partition type to use. Defaults to '${PARTITION_TYPE}'. Can be 'msdos' or 'gpt'."
    echo "  -c : The NFS export to mount and use as the pacman cache."
    echo "  -f : The filesystem to use. Currently 'ext4' and 'xfs' are supported, defaults to '${FS}'."
    echo "  -k : The keyboard mapping to use. Defaults to '${KEYMAP}'. See '/usr/share/kbd/keymaps/' for options."
    echo "  -l : The language to use. Defaults to '${LANG}'. See '/etc/locale.gen' for options."
    echo "  -m : Install a minimal system."
    echo "  -n : The hostname to use. Defaults to '${FQDN}'"
    echo "  -t : The timezone to use. Defaults to '${TIMEZONE}'. See '/usr/share/zoneinfo/' for options."
    echo
    echo "User provisioning"
    echo
    echo "Optionally you can create a file that defines user accounts that should be provisioned."
    echo "The format is:"
    echo
    echo "username,password,comment,extra_groups"
    echo
    echo "In the examples below, 'fred' is a sudo'er but 'barney' is not."
    echo
    echo "fred,fl1nt5t0n3,Fred Flintstone,wheel"
    echo "barney,ru88l3,Barney Rubble,"
    echo
    echo "All users are added to the following groups:"
    echo
    echo " - ${GROUPS}"
    echo
    exit 1
}

OPTSTRING=b:d:f:hk:l:mn:p:t:w:
while getopts ${OPTSTRING} OPT
do
    case ${OPT} in
        b) PARTITION_TYPE=${OPTARG};;
        c) NFS_CACHE=${OPTARG};;
        d) DSK=${OPTARG};;
        f) FS=${OPTARG};;
        h) usage;;
        k) KEYMAP=${OPTARG};;
        l) LANG=${OPTARG};;
        m) MINIMAL=1;;
        n) FQDN=${OPTARG};;
        p) PARTITION_LAYOUT=${OPTARG};;
        t) TIMEZONE=${OPTARG};;
        w) PASSWORD=${OPTARG};;
        *) usage;;
    esac
done

shift "$(( $OPTIND - 1 ))"

if [ ! -b /dev/${DSK} ]; then
    echo "ERROR! Target install disk not found."
    echo " - See `basename` -h"
    exit 1
fi

if [ "${FS}" != "ext4" ] && [ "${FS}" != "xfs" ]; then
    echo "ERROR! Filesystem ${FS} is not supported."
    echo " - See `basename` -h"
    exit 1
fi

if [ "${PARTITION_TYPE}" != "msdos" ] && [ "${PARTITION_TYPE}" != "gpt" ]; then
    echo "ERROR! Partition type ${PARTITION_TYPE} is not supported."
    echo " - See `basename` -h"
    exit 1
fi

if [ -z "${PASSWORD}" ]; then
    echo "ERROR! The 'root' password has not been set."
    echo " - See `basename` -h"
    exit 1
fi

if [ "${PARTITION_LAYOUT}" != "bsrh" ] && [ "${PARTITION_LAYOUT}" != "bsr" ] && [ "${PARTITION_LAYOUT}" != "br" ]; then
    echo "ERROR! I don't know what to do with '${PARTITION_LAYOUT}' partition layout."
    echo " - See `basename` -h"
    exit 1
fi

if [ ! -f /usr/share/zoneinfo/${TIMEZONE} ]; then
    echo "ERROR! I can't find the zone info for '${TIMEZONE}'."
    echo " - See `basename` -h"
    exit 1
fi

if [ -n "${NFS_CACHE}" ]; then
    systemctl start rpc-statd.service
    mount -t nfs ${NFS_CACHE} /var/cache/pacman/pkg
    if [ $? -ne 0 ]; then
        echo "ERROR! Unable to mount ${NFS_CACHE}"
        echo " - See `basename` -h"
        exit 1
    fi
fi

LANG_TEST=`grep ${LANG} /etc/locale.gen`
if [ $? -ne 0 ]; then
    echo "ERROR! The language you specified, '${LANG}', is not recognised."
    echo " * https://wiki.archlinux.org/index.php/Locale"
    usage
fi

KEYMAP_TEST=`ls -1 /usr/share/kbd/keymaps/*/*/*${KEYMAP}*`
if [ $? -ne 0 ]; then
    echo "ERROR! The keyboard mapping you specified, '${KEYMAP}', is not recognised."
    echo "  * https://wiki.archlinux.org/index.php/KEYMAP"
    usage
fi

if [ ! -f users.csv ]; then
    echo "################################################################################"
    echo "# WARNING! There is no 'users.csv' file. Exit now if you meant to provide one. #"
    echo "################################################################################"
    sleep 5
fi

# Detect the CPU
grep -q "^flags.*\blm\b" /proc/cpuinfo && CPU="x86_64" || CPU="i686"
if [ "${CPU}" != "i686" ] && [ "${CPU}" != "x86_64" ]; then
    echo "ERROR! `basename ${0}` is designed for i686 and x86_64 platforms only."
    echo " * Contributions welcome :-D"
    exit 1
fi

if [ "${HOSTNAME}" != "archiso" ]; then
    echo "PARACHUTE DEPLOYED! This script is not running from the Arch Linux install media."
    echo " * Exitting now to prevent untold chaos."
    exit 1
fi

# Load the keymap, remove the PC speaker module.
loadkeys -q ${KEYMAP}
rmmod -s pcspkr 2>/dev/null

# Calcualte a sane size for swap. Half RAM.
SWP=`awk '/MemTotal/ {printf( "%.0f\n", $2 / 1024 / 2 )}' /proc/meminfo`

# Partition the disk
# References
# - https://bbs.archlinux.org/viewtopic.php?id=145678
# - http://sprunge.us/WATU

# You may use "msdos" here instead of "gpt", if you want:
parted -s /dev/${DSK} mktable ${PARTITION_TYPE}

if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
    # /dev/sda1: 100 MB
    # /dev/sda2:  16 GB
    # /dev/sda3:  2 GB
    # /dev/sda4:  remaining GB

    boot=$((   1   +   100    ))
    root=$(( $boot + (1024*24) )) #FIXME - determine something sane for small disks
    swap=$(( $root + ${SWP} ))
    max=$(( $(cat /sys/block/sda/size) * 512 / 1024 / 1024 - 1 ))

    parted /dev/${DSK} unit MiB mkpart primary     1 $boot
    parted /dev/${DSK} unit MiB mkpart primary $boot $root
    parted /dev/${DSK} unit MiB mkpart primary linux-swap $root $swap
    parted /dev/${DSK} unit MiB mkpart primary $swap $max

    # Set boot flags
    parted /dev/${DSK} toggle 1 boot
    if [ "${PARTITION_TYPE}" == "gpt" ]; then
        sgdisk /dev/${DSK} --attributes=1:set:2
    fi

    mkfs.ext2 -F -L boot -m 0 /dev/${DSK}1

    if [ "${FS}" == "xfs" ]; then
        mkfs.xfs -f -L root /dev/${DSK}3
        mkfs.xfs -f -L home /dev/${DSK}4
    else
        mkfs.ext4 -F -L root -m 0 /dev/${DSK}3
        mkfs.ext4 -F -L home -m 0 /dev/${DSK}4
    fi

    mkswap -L swap /dev/${DSK}2
    swapon -L swap

    # Mount
    mount /dev/${DSK}3 /mnt
    mkdir -p /mnt/{boot,home}
    mount /dev/${DSK}1 /mnt/boot
    mount /dev/${DSK}4 /mnt/home
    ROOT_PARTITION="${DSK}3"

elif [ "${PARTITION_LAYOUT}" == "bsr" ]; then
    # /dev/sda1: 100 MB
    # /dev/sda2: swap
    # /dev/sda3: root - remaining GB

    boot=$((   1   +   100    ))
    swap=$(( $boot + ${SWP} ))
    max=$(( $(cat /sys/block/sda/size) * 512 / 1024 / 1024 - 1 ))

    parted /dev/${DSK} unit MiB mkpart primary     1 $boot
    parted /dev/${DSK} unit MiB mkpart primary linux-swap $boot $swap
    parted /dev/${DSK} unit MiB mkpart primary $swap $max

    # Set boot flags
    parted /dev/${DSK} toggle 1 boot
    if [ "${PARTITION_TYPE}" == "gpt" ]; then
        sgdisk /dev/${DSK} --attributes=1:set:2
    fi

    mkfs.ext2 -F -L boot -m 0 /dev/${DSK}1

    if [ "${FS}" == "xfs" ]; then
        mkfs.xfs -f -L root /dev/${DSK}3
    else
        mkfs.ext4 -F -L root -m 0 /dev/${DSK}3
    fi

    mkswap -L swap /dev/${DSK}2
    swapon -L swap

    # Mount
    mount /dev/${DSK}3 /mnt
    mkdir -p /mnt/{boot,home}
    mount /dev/${DSK}1 /mnt/boot
    ROOT_PARTITION="${DSK}3"

elif [ "${PARTITION_LAYOUT}" == "br" ]; then
    # /dev/sda1: 100 MB
    # /dev/sda2: remaining GB

    boot=$((   1   +   100    ))
    max=$(( $(cat /sys/block/sda/size) * 512 / 1024 / 1024 - 1 ))

    parted /dev/${DSK} unit MiB mkpart primary     1 $boot
    parted /dev/${DSK} unit MiB mkpart primary $boot $max

    # Set boot flags
    parted /dev/${DSK} toggle 1 boot
    if [ "${PARTITION_TYPE}" == "gpt" ]; then
        sgdisk /dev/${DSK} --attributes=1:set:2
    fi

    mkfs.ext2 -F -L boot -m 0 /dev/${DSK}1

    if [ "${FS}" == "xfs" ]; then
        mkfs.xfs -f -L root /dev/${DSK}2
    else
        mkfs.ext4 -F -L root -m 0 /dev/${DSK}2
    fi

    # Mount
    mount /dev/${DSK}2 /mnt
    mkdir -p /mnt/{boot,home}
    mount /dev/${DSK}1 /mnt/boot
    ROOT_PARTITION="${DSK}2"
fi

# Uncomment the multilib repo on the install ISO
if [ `uname -m` == "x86_64" ]; then
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
fi

# Base system
BASE_SYSTEM="base base-devel sudo syslinux wget"
pacstrap -c /mnt ${BASE_SYSTEM}

# Members of the 'wheel' group are sudoers
sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers

# Create the fstab, based on disk labels.
genfstab -L /mnt >> /mnt/etc/fstab

# Configure the hostname.
#arch-chroot /mnt hostnamectl set-hostname --static ${FQDN}
echo "${FQDN}" > /mnt/etc/hostname

# Prevent unwanted cache purges
#  - https://wiki.archlinux.org/index.php/Pacman_Tips#Network_shared_pacman_cache
sed -i 's/#CleanMethod = KeepInstalled/CleanMethod = KeepCurrent/' /mnt/etc/pacman.conf

# Configure timezone and hwclock
echo "${TIMEZONE}" > /mnt/etc/timezone
arch-chroot /mnt ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
arch-chroot /mnt hwclock --systohc --utc

# Configure console and keymap
echo KEYMAP=${KEYMAP}     >  /mnt/etc/vconsole.conf
echo FONT=${FONT}         >> /mnt/etc/vconsole.conf
echo FONT_MAP=${FONT_MAP} >> /mnt/etc/vconsole.conf

# Configure locale
sed -i "s/#${LANG}/${LANG}/" /mnt/etc/locale.gen
echo LANG=${LANG}             >   /mnt/etc/locale.conf
echo LC_COLLATE=${LC_COLLATE} >>  /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

# Configure SYSLINUX
wget --quiet http://projects.archlinux.org/archiso.git/plain/configs/releng/syslinux/splash.png -O /mnt/boot/syslinux/splash.png
sed -i 's/UI menu.c32/#UI menu.c32/' /mnt/boot/syslinux/syslinux.cfg
sed -i 's/#UI vesamenu.c32/UI vesamenu.c32/' /mnt/boot/syslinux/syslinux.cfg
sed -i 's/#MENU BACKGROUND/MENU BACKGROUND/' /mnt/boot/syslinux/syslinux.cfg
# Correct the root parition configuration
sed -i "s/sda3/${ROOT_PARTITION}/g" /mnt/boot/syslinux/syslinux.cfg

# Make the menu look pretty
cat >>/mnt/boot/syslinux/syslinux.cfg<<ENDSYSMENU
MENU WIDTH 78
MENU MARGIN 4
MENU ROWS 6
MENU VSHIFT 10
MENU TABMSGROW 14
MENU CMDLINEROW 14
MENU HELPMSGROW 16
MENU HELPMSGENDROW 29
ENDSYSMENU

# Configure 'nano' as the system default
echo "export EDITOR=nano" >> /mnt/etc/profile

# Disable pcspeaker
cat >/mnt/etc/modprobe.d/nobeep.conf<<ENDNOBEEP
# Do not load the pcspkr module on boot
blacklist pcspkr
ENDNOBEEP

# CPU Frequency scaling
# - https://wiki.archlinux.org/index.php/CPU_Frequency_Scaling
modprobe -q acpi-cpufreq
if [ $? -eq 0 ]; then
    echo "acpi-cpufreq" > /mnt/etc/modules-load.d/cpufreq.conf
fi

# Uncomment the multilib repo in the target
if [ `uname -m` == "x86_64" ]; then
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /mnt/etc/pacman.conf
fi

# If a full install is selected build the list of packages and install them.
if [ ${MINIMAL} -eq 0 ]; then
    # Create a list of package from the install ISO
    # Exclude `gcc-libs` because it is either already installed or will break
    # `multilib-devel`.
    pacman -Qqe | grep -v gcc-libs > /mnt/usr/local/etc/base-packages.txt

    #Add my essential packages to the base-packages.
    cat >>/mnt/usr/local/etc/base-packages.txt<<'ENDMYPACKAGES'
abs
arj
avahi
bash-completion
bzr
ca-certificates
cabextract
cifs-utils
chrony
colordiff
cvs
dbus
devtools
git
dmidecode
hexedit
htop
hub
lesspipe
lzop
mercurial
namcap
nss-mdns
openssh
p7zip
powertop
python2-paramiko
rpmextract
screen
sharutils
source-highlight
subversion
tree
unace
unrar
unzip
uudeview
wpa_supplicant
zip
ENDMYPACKAGES

    cat >/mnt/usr/local/bin/base-installer.sh<<'ENDOFSCRIPT'
#!/bin/bash

# Install packer
wget https://aur.archlinux.org/packages/pa/packer/packer.tar.gz -O /usr/local/src/packer.tar.gz
cd /usr/local/src
tar zxvf packer.tar.gz
cd packer
makepkg --asroot -s --noconfirm
pacman -U --noconfirm `ls -1t /usr/local/src/packer/*.pkg.tar.xz | head -1`

# Install base packages
pacman -Syy --noconfirm --needed `sort /usr/local/etc/base-packages.txt`

# Install multilib-devel
if [ `uname -m` == "x86_64" ]; then
    echo "
Y
Y
Y
Y
Y" | pacman -S --needed multilib-devel
fi

# Install pacman-color
packer -S --noconfirm --noedit pacman-color
ENDOFSCRIPT

    # Enter the chroot and complete the install.
    chmod +x /mnt/usr/local/bin/base-installer.sh
    arch-chroot /mnt /usr/local/bin/base-installer.sh
    sed -i 's/hosts: files dns/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4/' /mnt/etc/nsswitch.conf
    sed -i 's/! server ntp.public-server.org/server uk.pool.ntp.org/' /mnt/etc/chrony.conf
    arch-chroot /mnt systemctl start sshdgenkeys.service
    arch-chroot /mnt systemctl enable cronie.service
    arch-chroot /mnt systemctl enable chrony.service
    arch-chroot /mnt systemctl enable avahi-daemon.service
    arch-chroot /mnt systemctl enable sshd.service
    arch-chroot /mnt systemctl enable rpc-statd.service
    # Enable these removals when everything is stable.
    #rm /mnt/usr/local/bin/base-installer.sh
    #rm /mnt/usr/local/etc/base-packages.txt
fi

# Rebuild init and enable SYSLINUX
arch-chroot /mnt mkinitcpio -p linux
arch-chroot /mnt /usr/sbin/syslinux-install_update -iam

# Grab my dot files and populate /etc/skel
if [ ${MINIMAL} -eq 0 ]; then
    git clone https://github.com/flexiondotorg/dot-files.git /tmp/dot-files
    cp /tmp/dot-files/.bashrc /mnt/etc/skel/.bashrc
    cp /tmp/dot-files/.bash_logout /mnt/etc/skel/.bash_logout
fi

# Provision accounts if there is a `users.csv` file.
if [ -f users.csv ]; then
    IFS=$'\n';
    for USER in `cat users.csv`
    do
        _USERNAME=`echo ${USER} | cut -d',' -f1`
        _PLAINPASSWD=`echo ${USER} | cut -d',' -f2`
        _CRYPTPASSWD=`openssl passwd -crypt ${_PLAINPASSWD}`
        _COMMENT=`echo ${USER} | cut -d',' -f3`
        _EXTRA_GROUPS=`echo ${USER} | cut -d',' -f4`
        _BASE_GROUPS=${BASE_GROUPS}
        if [ "${_EXTRA_GROUPS}" != "" ]; then
            _GROUPS=${_BASE_GROUPS},${_EXTRA_GROUPS}
        else
            _GROUPS=${_BASE_GROUPS}
        fi
        arch-chroot /mnt useradd --password ${_CRYPTPASSWD} --comment "${_COMMENT}" --groups ${_GROUPS} --shell /bin/bash --create-home -g users ${_USERNAME}
        arch-chroot /mnt chown -R ${_USERNAME}:users /home/${_USERNAME}
    done
fi

# Change root password and configure the dot files.
PASSWORD_CRYPT=`openssl passwd -crypt ${PASSWORD}`
arch-chroot /mnt usermod --password ${PASSWORD_CRYPT} root
if [ ${MINIMAL} -eq 0 ]; then
    cp /tmp/dot-files/.bashrc /mnt/root/.bashrc
    cp /tmp/dot-files/.bash_logout /mnt/root/.bash_logout
fi

# Unmount
sync
if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
    umount /mnt/home
fi
umount /mnt/{boot,}
