#!/usr/bin/env bash

if [ -f common.sh ]; then
    source common.sh
else
    echo "ERROR! Could not source 'common.sh'"
    exit 1
fi

BASE_GROUPS="adm,audio,disk,lp,optical,storage,video,games,power,scanner"
DSK=""
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
SERVER=0
ENABLE_DISCARD=0
MACHINE=""
TARGET_PREFIX="/mnt"
CHROOT="chroot ${TARGET_PREFIX}"

CPU=`uname -m`
if [ "${CPU}" == "i686" ] || [ "${CPU}" == "x86_64" ]; then
    if [ "${HOSTNAME}" != "archiso" ]; then
        echo "PARACHUTE DEPLOYED! This script is not running from the Arch Linux install media."
        echo " - Exitting now to prevent untold chaos."
        exit 1
    else        
        MACHINE="pc"
    fi
elif [ "${CPU}" == "armv6l" ]; then
    if [ "${HOSTNAME}" != "alarmpi" ]; then
        echo "PARACHUTE DEPLOYED! This script is not running from a support Arch Linux ARM distro."
        echo " - Exitting now to prevent untold chaos."
        exit 1
    else        
        MACHINE="pi"
        DSK="mmcblk0" 
        TARGET_PREFIX=""
        CHROOT=""
    fi
else
    echo "ERROR! `basename ${0}` is designed for armv6l, i686, x86_64 platforms only."
    echo " - Contributions welcome - https://github.com/flexiondotorg/ArchInstaller/"
    exit 1
fi

function usage() {
    echo
    echo "Usage"
    if [ "${MACHINE}" == "pc" ]; then   
        echo "  ${0} -d sda -p bsrh -w P@ssw0rd -b ${PARTITION_TYPE} -f ${FS} -k ${KEYMAP} -l ${LANG} -n ${FQDN} -t ${TIMEZONE}"
    else
        echo "  ${0} -w P@ssw0rd -k ${KEYMAP} -l ${LANG} -n ${FQDN} -t ${TIMEZONE}"
    fi
    echo
    echo "Required parameters"
    if [ "${MACHINE}" == "pc" ]; then
        echo "  -d : The target device. For example, 'sda'."
        echo "  -p : The partition layout to use. One of: "
        echo "         'bsrh' : /boot, swap, /root and /home"
        echo "         'bsr'  : /boot, swap and /root"
        echo "         'br'   : /boot and /root, no swap."
    fi        
    echo "  -w : The root password."
    echo
    echo "Optional parameters"
    if [ "${MACHINE}" == "pc" ]; then
        echo "  -b : The partition type to use. Defaults to '${PARTITION_TYPE}'. Can be 'msdos' or 'gpt'."
        echo "  -f : The filesystem to use. 'btrfs', 'ext4', 'jfs', 'nilfs2' and 'xfs' are supported. Defaults to '${FS}'."        
    fi
    echo "  -c : The NFS export to mount and use as the pacman cache."
    echo "  -k : The keyboard mapping to use. Defaults to '${KEYMAP}'. See '/usr/share/kbd/keymaps/' for options."
    echo "  -l : The language to use. Defaults to '${LANG}'. See '/etc/locale.gen' for options."
    echo "  -m : Install a minimal system."
    echo "  -n : The hostname to use. Defaults to '${FQDN}'"
    echo "  -s : Install is for a server. -m overrides this."
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

OPTSTRING=b:c:d:f:hk:l:mn:p:t:sw:
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
        s) SERVER=1;;
        w) PASSWORD=${OPTARG};;
        *) usage;;
    esac
done

shift "$(( $OPTIND - 1 ))"

if [ "${MACHINE}" == "pc" ]; then
    if [ ! -b /dev/${DSK} ]; then
        echo "ERROR! Target install disk not found."
        echo " - See `basename ${0}` -h"
        exit 1
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

    if [ "${PARTITION_LAYOUT}" != "bsrh" ] && [ "${PARTITION_LAYOUT}" != "bsr" ] && [ "${PARTITION_LAYOUT}" != "br" ]; then
        echo "ERROR! I don't know what to do with '${PARTITION_LAYOUT}' partition layout."
        echo " - See `basename ${0}` -h"
        exit 1
    fi
fi    

if [ -z "${PASSWORD}" ]; then
    echo "ERROR! The 'root' password has not been provided."
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

echo
echo "Installation Summary"
echo
if [ "${MACHINE}" == "pc" ]; then
    echo " - Installation target : /dev/${DSK}"
    if [ `cat /sys/block/${DSK}/queue/rotational` == "0" ] && [ `cat /sys/block/${DSK}/removable` == "0" ]; then
        if [ -n "$(hdparm -I /dev/${DSK} 2>&1 | grep 'TRIM supported')" ]; then
            echo " - Disk type           : Solid state with TRIM."
            ENABLE_DISCARD=1
        else
            echo " - Disk type           : Solid state without TRIM."
        fi
    else
        echo " - Disk type           : Rotational"
    fi
    echo " - Disk label          : ${PARTITION_TYPE}"
    echo " - Partition layout    : ${PARTITION_LAYOUT}"
    echo " - File System         : ${FS}"
fi    
echo " - CPU                 : ${CPU}"
echo " - Hostname            : ${FQDN}"
echo " - Timezone            : ${TIMEZONE}"
echo " - Keyboard mapping    : ${KEYMAP}"
echo " - Locale              : ${LANG}"
if [ -n "${NFS_CACHE}" ]; then
    echo " - NFS Cache           : ${NFS_CACHE}"
fi

if [ ${MINIMAL} -eq 0 ]; then
    if [ ${SERVER} -eq 1 ]; then
        echo " - Installation type   : Server"
    else
        echo " - Installation type   : Standard"
    fi
else
    echo " - Installation type   : Minimal"
fi

if [ -f users.csv ]; then
    echo " - Provision users     : `cat users.csv | wc -l`"
else
    echo " - Provision users     : DISABLED!"
fi

if [ -f netcfg ]; then
    echo " - Configure network   : Yes"
else
    echo " - Configure network   : No"
fi

if [ "${MACHINE}" == "pc" ]; then
    echo
    echo "WARNING: `basename ${0}` is about to destroy everything on /dev/${DSK}!"
    echo "I make no guarantee that the installation of Arch Linux will succeed."
    echo "Press RETURN to try your luck or CTRL-C to cancel."
    read
else
    echo
    echo "WARNING: `basename ${0}` is about to start installing!"
    echo "I make no guarantee that the installation of Arch Linux ARM will succeed."
    echo "Press RETURN to try your luck or CTRL-C to cancel."
    read        
fi    

# Load the keymap and remove the PC speaker module.
loadkeys -q ${KEYMAP}
rmmod -s pcspkr 2>/dev/null

if [ "${MACHINE}" == "pc" ]; then
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
        ROOT_PARTITION="${DSK}3"
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
        ROOT_PARTITION="${DSK}2"
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
    mkfs.ext2 -F -L boot -m 0 -q /dev/${DSK}1 >/dev/null
    echo "==> Making /root filesystem : ${FS}"
    ${MKFS} -L root /dev/${ROOT_PARTITION} >/dev/null
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        echo "==> Making /home filesystem : ${FS}"
        ${MKFS} -L home /dev/${DSK}4 >/dev/null
    fi

    # Enable swap
    if [ "${PARTITION_LAYOUT}" == "bsrh" ] || [ "${PARTITION_LAYOUT}" == "bsr" ]; then
        echo -n "==> "
        mkswap -f -L swap /dev/${DSK}2
        swapon /dev/${DSK}2
    fi

    # Mount
    echo "==> Mounting filesystems"
    mount /dev/${ROOT_PARTITION} ${TARGET_PREFIX} >/dev/null
    mkdir -p ${TARGET_PREFIX}/{boot,home}
    mount /dev/${DSK}1 ${TARGET_PREFIX}/boot >/dev/null
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        mount /dev/${DSK}4 ${TARGET_PREFIX}/home >/dev/null
    fi
fi

# Base system
if [ "${MACHINE}" == "pc" ]; then
    pacstrap -c ${TARGET_PREFIX} base base-devel syslinux terminus-font
else
    pacman -S --noconfirm --needed base base-devel terminus-font
fi    

# Prevent unwanted cache purges
#  - https://wiki.archlinux.org/index.php/Pacman_Tips#Network_shared_pacman_cache
sed -i 's/#CleanMethod = KeepInstalled/CleanMethod = KeepCurrent/' ${TARGET_PREFIX}/etc/pacman.conf

if [ "${MACHINE}" == "pc" ]; then
    # Uncomment the multilib repo on the install ISO and the target
    if [ "${CPU}" == "x86_64" ]; then
        sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
        sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' ${TARGET_PREFIX}/etc/pacman.conf
    fi

    # Create /etc/fstab
    genfstab -t UUID -p ${TARGET_PREFIX} >> ${TARGET_PREFIX}/etc/fstab

    # TODO - Test this works. None of my SSDs are TRIM compatible.
    if [ ${ENABLE_DISCARD} -eq 1 ]; then
        :
        #sed -i 's/rw,relatime/rw,relatime,discard/g' /mnt/etc/fstab
    fi

    # Configure the hostname.
    # This is the systemd way but doesn't seem to work in a `chroot`.
    echo "${FQDN}" > ${TARGET_PREFIX}/etc/hostname    
else    
    # Configure the hostname.
    hostnamectl set-hostname --static ${FQDN}
fi    

# Configure timezone and hwclock
echo "${TIMEZONE}" > ${TARGET_PREFIX}/etc/timezone

if [ "${MACHINE}" == "pc" ]; then
    ${CHROOT} ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    ${CHROOT} hwclock --systohc --utc
else
    rm /etc/localtime 2>/dev/null
    ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
fi    

# Configure console font and keymap
echo KEYMAP=${KEYMAP}     >  ${TARGET_PREFIX}/etc/vconsole.conf
echo FONT=${FONT}         >> ${TARGET_PREFIX}/etc/vconsole.conf
echo FONT_MAP=${FONT_MAP} >> ${TARGET_PREFIX}/etc/vconsole.conf

# Configure init things
check_vga
update_early_hooks "consolefont keymap"
update_early_modules ${VIDEO_KMS}

# Configure kernel module options
if [ -n "${VIDEO_MODPROBE}" ] && [ -n "${VIDEO_KMS}" ]; then
    echo "${VIDEO_MODPROBE}" > ${TARGET_PREFIX}/etc/modprobe.d/${VIDEO_KMS}.conf
fi   

# Configure locale
sed -i "s/#${LANG}/${LANG}/" ${TARGET_PREFIX}/etc/locale.gen
echo LANG=${LANG}             >   ${TARGET_PREFIX}/etc/locale.conf
echo LC_COLLATE=${LC_COLLATE} >>  ${TARGET_PREFIX}/etc/locale.conf
${CHROOT} locale-gen

# Configure SYSLINUX
if [ "${MACHINE}" == "pc" ]; then
    cp splash.png ${TARGET_PREFIX}/boot/syslinux/splash.png
    cp terminus.psf ${TARGET_PREFIX}/boot/syslinux/terminus.psf
    sed -i 's/UI menu.c32/#UI menu.c32/' ${TARGET_PREFIX}/boot/syslinux/syslinux.cfg
    sed -i 's/#UI vesamenu.c32/UI vesamenu.c32/' ${TARGET_PREFIX}/boot/syslinux/syslinux.cfg
    sed -i 's/#MENU BACKGROUND/MENU BACKGROUND/' ${TARGET_PREFIX}/boot/syslinux/syslinux.cfg
    # Correct the root parition configuration
    sed -i "s/sda3/\/disk\/by-label\/root/g" ${TARGET_PREFIX}/boot/syslinux/syslinux.cfg
    # Make the menu look pretty
    cat >>${TARGET_PREFIX}/boot/syslinux/syslinux.cfg<<ENDSYSMENU
    
MENU WIDTH 78
MENU MARGIN 4
MENU ROWS 6
MENU VSHIFT 10
MENU TABMSGROW 14
MENU CMDLINEROW 14
MENU HELPMSGROW 16
MENU HELPMSGENDROW 29
FONT terminus.psf
ENDSYSMENU
fi

# Configure 'nano' as the system default
echo "export EDITOR=nano" >> ${TARGET_PREFIX}/etc/profile

# Disable PC speaker - I hate that thing!
echo "blacklist pcspkr" > ${TARGET_PREFIX}/etc/modprobe.d/blacklist-pcspkr.conf

# CPU Frequency scaling
# - https://wiki.archlinux.org/index.php/CPU_Frequency_Scaling
modprobe -q acpi-cpufreq
if [ $? -eq 0 ]; then
    echo "acpi-cpufreq" > ${TARGET_PREFIX}/etc/modules-load.d/acpi-cpufreq.conf
else
    modprobe -q powernow_k8
    if [ $? -eq 0 ]; then
        echo "powernow_k8" > ${TARGET_PREFIX}/etc/modules-load.d/powernow_k8.conf
    fi
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
Y" | pacstrap -c -i ${TARGET_PREFIX} multilib-devel
    fi

    if [ "${MACHINE}" == "pc" ]; then
        pacstrap -c ${TARGET_PREFIX} `cat extra-packages.txt`
        EXTRA_RET=$?
        umount -f ${TARGET_PREFIX}/sys/fs/cgroup/{systemd,} 2>/dev/null
        umount -f ${TARGET_PREFIX}/sys 2>/dev/null
    else        
        # Some packages are not available on Arch Linux ARM
        pacman -S --noconfirm --needed `cat extra-packages.txt | grep -v pcmciautils | grep -v syslinux`
        EXTRA_RET=$?        
    fi

    if [ ${EXTRA_RET} -ne 0 ]; then
        echo "ERROR! Installing extra-packages.txt failed. Please try again."            
        exit 1
    fi            

    # Configure mDNS
    sed -i 's/hosts: files dns/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4/' ${TARGET_PREFIX}/etc/nsswitch.conf
    # Members of the `wheel` group are sudoers.
    sed -i '/%wheel ALL=(ALL) ALL/s/^#//' ${TARGET_PREFIX}/etc/sudoers
    ${CHROOT} systemctl start sshdgenkeys.service    
    ${CHROOT} systemctl enable sshd.service
    ${CHROOT} systemctl enable openntpd.service

    # These services should not be enable for a "server".
    if [ ${SERVER} -eq 0 ]; then
        ${CHROOT} systemctl enable avahi-daemon.service
        ${CHROOT} systemctl enable rpc-statd.service
    fi

    # Install `packer` and `pacman-color`.
    if [ "${MACHINE}" == "pc" ]; then
        cp packer-installer.sh ${TARGET_PREFIX}/usr/local/bin/packer-installer.sh
        chmod +x ${TARGET_PREFIX}/usr/local/bin/packer-installer.sh
        ${CHROOT} /usr/local/bin/packer-installer.sh
        rm ${TARGET_PREFIX}/usr/local/bin/packer-installer.sh
    else
        # packer is in the alarmpi AUR repository
        pacman -S --noconfirm packer
    fi        

    # Install my dot files and configure the root user shell.
    rm -rf /tmp/dot-files 2>/dev/null
    git clone https://github.com/flexiondotorg/dot-files.git /tmp/dot-files
    rm -rf /tmp/dot-files/{.git,*.txt,*.md}
    rsync -aq /tmp/dot-files/ ${TARGET_PREFIX}/
    rsync -aq /tmp/dot-files/etc/skel/ ${TARGET_PREFIX}/root/
fi

# Rebuild init and update SYSLINUX
${CHROOT} systemctl enable cronie.service

if [ "${MACHINE}" == "pc" ]; then
    ${CHROOT} mkinitcpio -p linux
    ${CHROOT} /usr/sbin/syslinux-install_update -iam
fi    

# Configure the network if a configuration exists.
if [ -f netcfg ]; then
    cp netcfg ${TARGET_PREFIX}/etc/network.d/mynetwork
    ${CHROOT} systemctl enable netcfg@mynetwork
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
        ${CHROOT} useradd --password ${_CRYPTPASSWD} --comment "${_COMMENT}" --groups ${_GROUPS} --shell /bin/bash --create-home -g users ${_USERNAME}
        # If the user already exists (Possible on a Raspberry Pi) the above may error.
        # So modify the user, on error, to ensure the correct configuration is applied.
        if [ $? -ne 0 ]; then
            ${CHROOT} usermod --password ${_CRYPTPASSWD} --comment "${_COMMENT}" --groups ${_GROUPS} --shell /bin/bash --create-home -g users --append ${_USERNAME}
        fi

        # Put ArchInstaller in the home directory of users in the `wheel` group.
        PROVISION_ARCHINSTALLER=`echo ${_GROUPS} | grep wheel`
        if [ $? -eq 0 ]; then
            mkdir -p ${TARGET_PREFIX}/home/${_USERNAME}/Source/flexiondotorg/ArchInstaller/
            rsync -aq `pwd`/ ${TARGET_PREFIX}/home/${_USERNAME}/Source/flexiondotorg/ArchInstaller/
            ${CHROOT} chown -R ${_USERNAME}:users /home/${_USERNAME}
        fi
    done
fi

# Change root password.
PASSWORD_CRYPT=`openssl passwd -crypt ${PASSWORD}`
${CHROOT} usermod --password ${PASSWORD_CRYPT} root

# Unmount
sync
if [ -n "${NFS_CACHE}" ]; then
    echo "${NFS_CACHE} /var/cache/pacman/pkg nfs defaults,noauto,x-systemd.automount 0 0" >> ${TARGET_PREFIX}/etc/fstab
    if [ "${MACHINE}" == "pc" ]; then
        umount -f /var/cache/pacman/pkg
    fi        
fi

if [ "${MACHINE}" == "pc" ]; then
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        umount -f ${TARGET_PREFIX}/home
    fi
    umount -f ${TARGET_PREFIX}/sys/fs/cgroup/{systemd,} 2>/dev/null
    umount -f ${TARGET_PREFIX}/sys 2>/dev/null
    umount -f ${TARGET_PREFIX}/{boot,}
    swapoff -a
fi    

echo "All done!"
