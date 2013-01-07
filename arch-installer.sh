#!/usr/bin/env bash

BASE_GROUPS="adm,audio,disk,lp,optical,storage,video,games,power,scanner"
DSK=""
PFX=""
NFS_CACHE=""
FQDN="arch.example.org"
TIMEZONE="Europe/London"
KEYMAP="uk"
LANG="en_GB.UTF-8"
LC_COLLATE="C"
FONT="ter-116b"
FONT_MAP="8859-1_to_uni"
PASSWORD=""
FS="ext4"
PARTITION_TYPE="msdos"
PARTITION_LAYOUT=""
MINIMAL=0
ENABLE_DISCARD=0

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
    echo "  -f : The filesystem to use. 'btrfs', 'ext4', 'jfs', 'nilfs2' and 'xfs' are supported. Defaults to '${FS}'."
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
    echo " - ${BASE_GROUPS}"
    echo
    exit 1
}

OPTSTRING=b:c:d:f:hk:l:mn:p:t:w:
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
    echo " - See `basename ${0}` -h"
    exit 1
fi

# Adjust partition prefixes based on disk device
if [ `echo ${DSK} | cut -c1-2` == "dm" ]; then
    PFX="p"
fi

case ${FS} in
    "btrfs")  MKFS="mkfs.btrfs";;
    "ext2")   MKFS="mkfs.ext2 -F -m 0 -q";;
    "ext3")   MKFS="mkfs.ext3 -F -m 0 -q";;
    "ext4")   MKFS="mkfs.ext4 -F -m 0 -q";;
    "jfs")    MKFS="mkfs.jfs -q";;
    "nilfs2") MKFS="mkfs.nilfs2 -q";;
    "xfs")    MKFS="mkfs.xfs -f -q";;
    *) echo "ERROR! Filesystem ${FS} is not supported."
       echo " - See `basename ${0}` -h"
       exit 1
       ;;
esac

if [ "${PARTITION_TYPE}" != "msdos" ] && [ "${PARTITION_TYPE}" != "gpt" ]; then
    echo "ERROR! Partition type ${PARTITION_TYPE} is not supported."
    echo " - See `basename ${0}` -h"
    exit 1
fi

if [ -z "${PASSWORD}" ]; then
    echo "ERROR! The 'root' password has not been provided."
    echo " - See `basename ${0}` -h"
    exit 1
fi

if [ "${PARTITION_LAYOUT}" != "bsrh" ] && [ "${PARTITION_LAYOUT}" != "bsr" ] && [ "${PARTITION_LAYOUT}" != "br" ]; then
    echo "ERROR! I don't know what to do with '${PARTITION_LAYOUT}' partition layout."
    echo " - See `basename ${0}` -h"
    exit 1
fi

if [ ! -f /usr/share/zoneinfo/${TIMEZONE} ]; then
    echo "ERROR! I can't find the zone info for '${TIMEZONE}'."
    echo " - See `basename ${0}` -h"
    exit 1
fi

LANG_TEST=`grep ${LANG} /etc/locale.gen`
if [ $? -ne 0 ]; then
    echo "ERROR! The language you specified, '${LANG}', is not recognised."
    echo " - See https://wiki.archlinux.org/index.php/Locale"
    exit 1
fi

KEYMAP_TEST=`ls -1 /usr/share/kbd/keymaps/*/*/*${KEYMAP}*`
if [ $? -ne 0 ]; then
    echo "ERROR! The keyboard mapping you specified, '${KEYMAP}', is not recognised."
    echo " - See https://wiki.archlinux.org/index.php/KEYMAP"
    exit 1
fi

CPU=`uname -m`
if [ "${CPU}" != "i686" ] && [ "${CPU}" != "x86_64" ]; then
    echo "ERROR! `basename ${0}` is designed for i686 and x86_64 platforms only."
    echo " - Contributions welcome - https://github.com/flexiondotorg/ArchInstaller/"
    exit 1
fi

if [ -n "${NFS_CACHE}" ]; then
    systemctl start rpc-statd.service >/dev/null
    mount -t nfs ${NFS_CACHE} /var/cache/pacman/pkg >/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR! Unable to mount ${NFS_CACHE}"
        echo " - See `basename ${0}` -h"
        exit 1
    fi

    # Make sure the cache is writeable
    touch /var/cache/pacman/pkg/cache.test 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR! The NFS cache, ${NFS_CACHE}, is read-only."
        exit 1
    else
        rm /var/cache/pacman/pkg/cache.test 2>/dev/null
    fi
fi

if [ "${HOSTNAME}" != "archiso" ]; then
    echo "PARACHUTE DEPLOYED! This script is not running from the Arch Linux install media."
    echo " - Exitting now to prevent untold chaos."
    exit 1
fi

echo
echo "Installation Summary"
echo
echo " - Installation target : /dev/${DSK}"
if [ `cat /sys/block/${DSK}/queue/rotational` == "0" ] && [ `cat /sys/block/${DSK}/removable` == "0" ]; then
    if [ -n "$(hdparm -I /dev/${DSK} 2>&1 | grep 'TRIM supported')" ]; then
        echo " -  Disk type           : Solid state with TRIM."
        ENABLE_DISCARD=1
    else
        echo " -  Disk type           : Solid state without TRIM."
    fi
else
    echo " - Disk type           : Rotational"
fi
echo " - Disk label          : ${PARTITION_TYPE}"
echo " - Partition layout    : ${PARTITION_LAYOUT}"
echo " - File System         : ${FS}"
echo " - CPU                 : ${CPU}"
echo " - Hostname            : ${FQDN}"
echo " - Timezone            : ${TIMEZONE}"
echo " - Keyboard mapping    : ${KEYMAP}"
echo " - Locale              : ${LANG}"
if [ -n "${NFS_CACHE}" ]; then
    echo " - NFS Cache           : ${NFS_CACHE}"
fi

if [ ${MINIMAL} -eq 0 ]; then
    echo " - Installation type   : Standard"
else
    echo " - Installation type   : Minimal"
fi

if [ -f users.csv ]; then
    echo " - Provision users     : `cat users.csv | wc -l`"
else
    echo " - Provision users     : DISABLED!"
fi

echo
echo "WARNING: `basename ${0}` is about to destroy everything on /dev/${DSK}!"
echo "I make no guarantee that the installation of Arch Linux will succeed."
echo "Press RETURN to try your luck or CTRL-C to cancel."
read

# Load the keymap and remove the PC speaker module.
loadkeys -q ${KEYMAP}
rmmod -s pcspkr 2>/dev/null

# Partition the disk
#  - https://bbs.archlinux.org/viewtopic.php?id=145678
#  - http://sprunge.us/WATU
echo "==> Initialising disk /dev/${DSK}: ${PARTITION_TYPE}"
parted -s /dev/${DSK} mktable ${PARTITION_TYPE} >/dev/null

# Calculate common partition sizes.
swap_size=`awk '/MemTotal/ {printf( "%.0f\n", $2 / 1000 )}' /proc/meminfo`
boot_end=$(( 1 + 96 ))
swap_end=$(( $boot_end + ${swap_size} ))
max=$(( $(cat /sys/block/${DSK}/size) * 512 / 1024 / 1024 - 1 ))

if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
    # If the total space available is less than 'root_max' (in Gb) then make
    # the /root partition half the total disk capcity.
    root_max=24
    if [ $(( $max )) -le $(( (${root_max} * 1024) + ${swap_size} )) ]; then
        root_end=$(( $swap_end + ( $max / 2 )  ))
    else
        root_end=$(( $swap_end + ( $root_max * 1024 ) ))
    fi
else
    root_end=$max
fi

# Partition the disk.
# /boot
echo "==> Creating /boot partition"
parted -s /dev/${DSK} unit MiB mkpart primary 1 $boot_end >/dev/null

if [ "${PARTITION_LAYOUT}" == "bsrh" ] || [ "${PARTITION_LAYOUT}" == "bsr" ]; then
    # swap and /root
    ROOT_PARTITION="${DSK}${PFX}3"
    echo "==> Creating swap partition"
    parted -s /dev/${DSK} unit MiB mkpart primary linux-swap $boot_end $swap_end >/dev/null
    echo "==> Creating /root partition"
    parted -s /dev/${DSK} unit MiB mkpart primary $swap_end $root_end >/dev/null
    # /home
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        echo "==> Creating /home partition"
        parted -s /dev/${DSK} unit MiB mkpart primary $root_end $max >/dev/null
    fi
elif [ "${PARTITION_LAYOUT}" = "br" ]; then
    # /root
    ROOT_PARTITION="${DSK}${PFX}2"
    echo "==> Creating /root partition"
    parted -s /dev/${DSK} unit MiB mkpart primary $boot_end $root_end >/dev/null
fi

# Set boot flags
echo "==> Setting /dev/${DSK} bootable"
parted -s /dev/${DSK} toggle 1 boot >/dev/null
if [ "${PARTITION_TYPE}" == "gpt" ]; then
    sgdisk /dev/${DSK} --attributes=1:set:2 >/dev/null
fi

# Make the file systems.
echo "==> Making /boot filesystem : ext2"
mkfs.ext2 -F -L boot -m 0 -q /dev/${DSK}${PFX}1 >/dev/null
echo "==> Making /root filesystem : ${FS}"
${MKFS} -L root /dev/${ROOT_PARTITION} >/dev/null
if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
    echo "==> Making /home filesystem : ${FS}"
    ${MKFS} -L home /dev/${DSK}${PFX}4 >/dev/null
fi

# Enable swap
if [ "${PARTITION_LAYOUT}" == "bsrh" ] || [ "${PARTITION_LAYOUT}" == "bsr" ]; then
    echo -n "==> "
    mkswap -f -L swap /dev/${DSK}${PFX}2
    swapon /dev/${DSK}${PFX}2
fi

# Mount
echo "==> Mounting filesystems"
mount /dev/${ROOT_PARTITION} /mnt >/dev/null
mkdir -p /mnt/{boot,home}
mount /dev/${DSK}${PFX}1 /mnt/boot >/dev/null
if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
    mount /dev/${DSK}${PFX}4 /mnt/home >/dev/null
fi

# Base system
BASE_SYSTEM="base base-devel syslinux terminus-font"
pacstrap -c /mnt ${BASE_SYSTEM}

# Prevent unwanted cache purges
#  - https://wiki.archlinux.org/index.php/Pacman_Tips#Network_shared_pacman_cache
sed -i 's/#CleanMethod = KeepInstalled/CleanMethod = KeepCurrent/' /mnt/etc/pacman.conf

# Uncomment the multilib repo on the install ISO and the target
if [ "${CPU}" == "x86_64" ]; then
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
    sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /mnt/etc/pacman.conf
fi

# Create /etc/fstab
genfstab -t UUID -p /mnt >> /mnt/etc/fstab
# TODO - Test this works. None of my SSDs are TRIM compatible.
if [ ${ENABLE_DISCARD} -eq 1 ]; then
    :
    #sed -i 's/rw,relatime/rw,relatime,discard/g' /mnt/etc/fstab
fi

# Configure the hostname.
# This is the systemd way but doesn't seem to work in a `chroot`.
#arch-chroot /mnt hostnamectl set-hostname --static ${FQDN}
echo "${FQDN}" > /mnt/etc/hostname

# Configure timezone and hwclock
echo "${TIMEZONE}" > /mnt/etc/timezone
arch-chroot /mnt ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
arch-chroot /mnt hwclock --systohc --utc

# Configure console font and keymap
echo KEYMAP=${KEYMAP}     >  /mnt/etc/vconsole.conf
echo FONT=${FONT}         >> /mnt/etc/vconsole.conf
echo FONT_MAP=${FONT_MAP} >> /mnt/etc/vconsole.conf
sed -i 's/filesystems usbinput fsck"/filesystems usbinput fsck consolefont keymap"/' /mnt/etc/mkinitcpio.conf

# Configure locale
sed -i "s/#${LANG}/${LANG}/" /mnt/etc/locale.gen
echo LANG=${LANG}             >   /mnt/etc/locale.conf
echo LC_COLLATE=${LC_COLLATE} >>  /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

# Configure SYSLINUX
cp splash.png /mnt/boot/syslinux/splash.png
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

# Disable PC speaker - I hate that thing!
echo "blacklist pcspkr" > /mnt/etc/modprobe.d/blacklist-pcspkr.conf

# CPU Frequency scaling
# - https://wiki.archlinux.org/index.php/CPU_Frequency_Scaling
modprobe -q acpi-cpufreq
if [ $? -eq 0 ]; then
    echo "acpi-cpufreq" > /mnt/etc/modules-load.d/acpi-cpufreq.conf
fi

# Install and configure the extra packages
if [ ${MINIMAL} -eq 0 ]; then
    # Install multilib-devel
    if [ "${CPU}" == "x86_64" ]; then
    echo "
Y
Y
Y
Y
Y" | pacstrap -c -i /mnt multilib-devel
    fi

    pacstrap -c /mnt `cat extra-packages.txt`

    # Unmount /sys in the target
    umount /mnt/sys/fs/cgroup/{systemd,} >/dev/null
    umount /mnt/sys >/dev/null

    # Configure mDNS
    sed -i 's/hosts: files dns/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4/' /mnt/etc/nsswitch.conf
    # Members of the `wheel` group are sudoers.
    sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
    arch-chroot /mnt systemctl start sshdgenkeys.service
    arch-chroot /mnt systemctl enable ntpd.service
    arch-chroot /mnt systemctl enable avahi-daemon.service
    arch-chroot /mnt systemctl enable sshd.service
    arch-chroot /mnt systemctl enable rpc-statd.service

    # Install `packer` and `pacman-color`.
    cp packer-installer.sh /mnt/usr/local/bin/packer-installer.sh
    chmod +x /mnt/usr/local/bin/packer-installer.sh
    arch-chroot /mnt /usr/local/bin/packer-installer.sh
    rm /mnt/usr/local/bin/packer-installer.sh

    # Install my dot files and configure the root user shell.
    git clone https://github.com/flexiondotorg/dot-files.git /tmp/dot-files
    rm -rf /tmp/dot-files/{.git,*.txt,*.md}
    cp -Rf /tmp/dot-files/* /mnt/
    cp -Rf /tmp/dot-files/etc/skel/* /mnt/root/
fi

# Rebuild init and update SYSLINUX
arch-chroot /mnt systemctl enable cronie.service

arch-chroot /mnt mkinitcpio -p linux
arch-chroot /mnt /usr/sbin/syslinux-install_update -iam

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

        # Put ArchInstaller in the home directory of users in the `wheel` group.
        PROVISION_ARCHINSTALLER=`echo ${_GROUPS} | grep wheel`
        if [ $? -eq 0 ]; then
            mkdir -p /mnt/home/${_USERNAME}/Source/Mine/ArchInstaller/
            rsync -aq `pwd`/ /mnt/home/${_USERNAME}/Source/Mine/ArchInstaller/
            arch-chroot /mnt chown -R ${_USERNAME}:users /home/${_USERNAME}
        fi
    done
fi

# Change root password.
PASSWORD_CRYPT=`openssl passwd -crypt ${PASSWORD}`
arch-chroot /mnt usermod --password ${PASSWORD_CRYPT} root

# Unmount
sync
if [ -n "${NFS_CACHE}" ]; then
    echo "${NFS_CACHE} /var/cache/pacman/pkg nfs defaults,noauto,x-systemd.automount 0 0" >> /mnt/etc/fstab
    umount /var/cache/pacman/pkg
fi
if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
    umount /mnt/home
fi
umount /mnt/sys/fs/cgroup/{systemd,} >/dev/null
umount /mnt/sys >/dev/null
umount /mnt/{boot,}
swapoff -a

echo "All done!"
