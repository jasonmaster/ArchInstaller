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
INSTALL_TYPE="desktop"
ENABLE_DISCARD=0
MACHINE="pc"
TARGET_PREFIX="/mnt"
CPU=`uname -m`
DE="shell"

if [ "${CPU}" == "i686" ] || [ "${CPU}" == "x86_64" ]; then
    if [ "${HOSTNAME}" != "archiso" ]; then
        echo "PARACHUTE DEPLOYED! This script is not running from the Arch Linux install media."
        echo " - Exitting now to prevent untold chaos."
        exit 1
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
        echo "  -f : The filesystem to use. 'bfs', 'btrfs', 'ext4', 'f2fs, 'jfs', 'nilfs2', 'ntfs' and 'xfs' are supported. Defaults to '${FS}'."
    fi
    echo "  -c : The NFS export to mount and use as the pacman cache."
    echo "  -e : The desktop environment to install. Defaults to '${DE}'. Can be 'shell', 'xorg', 'gnome' or 'kde'"
    echo "  -k : The keyboard mapping to use. Defaults to '${KEYMAP}'. See '/usr/share/kbd/keymaps/' for options."
    echo "  -l : The language to use. Defaults to '${LANG}'. See '/etc/locale.gen' for options."
    echo "  -n : The hostname to use. Defaults to '${FQDN}'"
    echo "  -r : The computer role. Defaults to '${INSTALL_TYPE}'. Can be 'desktop', 'server', 'minimal'."
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

OPTSTRING=b:c:d:e:f:hk:l:n:p:r:t:w:
while getopts ${OPTSTRING} OPT
do
    case ${OPT} in
        b) PARTITION_TYPE=${OPTARG};;
        c) NFS_CACHE=${OPTARG};;
        d) DSK=${OPTARG};;
        e) DE=${OPTARG};;
        f) FS=${OPTARG};;
        h) usage;;
        k) KEYMAP=${OPTARG};;
        l) LANG=${OPTARG};;
        n) FQDN=${OPTARG};;
        p) PARTITION_LAYOUT=${OPTARG};;
        r) INSTALL_TYPE=${OPTARG};;
        t) TIMEZONE=${OPTARG};;
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

    MKFS_L="-L"
    case ${FS} in
        "bfs")    MKFS="mkfs.bfs"
                  MKFS_L="-V";;
        "btrfs")  MKFS="mkfs.btrfs";;
        "ext2")   MKFS="mkfs.ext2 -F -m 0 -q";;
        "ext3")   MKFS="mkfs.ext3 -F -m 0 -q";;
        "ext4")   MKFS="mkfs.ext4 -F -m 0 -q";;
        "f2fs")   MKFS="mkfs.f2fs"
                  MKFS_L="-l";;
        "jfs")    MKFS="mkfs.jfs -q";;
        "nilfs2") MKFS="mkfs.nilfs2 -q";;
        "ntfs")   MKFS="mkfs.ntfs -q";;
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

if [ "${INSTALL_TYPE}" != "desktop" ] && [ "${INSTALL_TYPE}" != "server" ] && [ "${INSTALL_TYPE}" != "minimal" ]; then
    echo "ERROR! '${INSTALL_TYPE}' is not a supported computer role."
    exit 1
fi

if [ "${DE}" != "shell" ] && [ "${DE}" != "xorg" ] && [ "${DE}" != "gnome" ] && [ "${DE}" != "kde" ]; then
    echo "ERROR! '${DE}' is not a supported desktop environemt."
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
    echo
    echo "Testing NFS cache : ${NFS_CACHE}"
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

echo " - Installation type   : ${INSTALL_TYPE}"
echo " - Desktop Environment : ${DE}"

if [ -f users.csv ]; then
    echo " - Provision users     : `cat users.csv | wc -l`"
else
    echo " - Provision users     : DISABLED!"
fi

if [ -f netctl ]; then
    echo " - Configure network   : Yes"
else
    echo " - Configure network   : No"
fi

echo
if [ "${MACHINE}" == "pc" ]; then
    echo "WARNING: `basename ${0}` is about to destroy everything on /dev/${DSK}!"
else
    echo "WARNING: `basename ${0}` is about to start installing!"
fi
echo "I make no guarantee that the installation of Arch Linux will succeed."
echo "Press RETURN to try your luck or CTRL-C to cancel."
read

# Load the keymap and remove the PC speaker module.
loadkeys -q ${KEYMAP}

if [ "${MACHINE}" == "pc" ]; then
    echo "==> Clearing partition table on /dev/${DSK}"
    sgdisk --zap /dev/${DSK} >/dev/null 2>&1
    echo "==> Destroying magic strings and signatures on /dev/${DSK}"
    dd if=/dev/zero of=/dev/${DSK} bs=512 count=2048 >/dev/null 2>&1
    wipefs -a /dev/${DSK} 2>/dev/null
    # Partition the disk https://bbs.archlinux.org/viewtopic.php?id=145678 http://sprunge.us/WATU
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

    echo "==> Creating /boot partition"
    parted -a optimal -s /dev/${DSK} unit MiB mkpart primary 1 $boot_end >/dev/null

    if [ "${PARTITION_LAYOUT}" == "bsrh" ] || [ "${PARTITION_LAYOUT}" == "bsr" ]; then
        ROOT_PARTITION="${DSK}3"
        echo "==> Creating swap partition"
        parted -a optimal -s /dev/${DSK} unit MiB mkpart primary linux-swap $boot_end $swap_end >/dev/null
        echo "==> Creating /root partition"
        parted -a optimal -s /dev/${DSK} unit MiB mkpart primary $swap_end $root_end >/dev/null
        if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
            echo "==> Creating /home partition"
            parted -a optimal -s /dev/${DSK} unit MiB mkpart primary $root_end $max >/dev/null
        fi
    elif [ "${PARTITION_LAYOUT}" = "br" ]; then
        ROOT_PARTITION="${DSK}2"
        echo "==> Creating /root partition"
        parted -a optimal -s /dev/${DSK} unit MiB mkpart primary $boot_end $root_end >/dev/null
    fi

    echo "==> Setting /dev/${DSK} bootable"
    parted -a optimal -s /dev/${DSK} toggle 1 boot >/dev/null
    if [ "${PARTITION_TYPE}" == "gpt" ]; then
        sgdisk /dev/${DSK} --attributes=1:set:2 >/dev/null
    fi

    partprobe /dev/${DSK}
    if [[ $? -gt 0 ]]; then
        echo "ERROR! Partitioning /dev/${DSK} failed."
        exit 1
    fi

    # Wait until `/dev` has initialized correct devices
    udevadm settle

    echo "==> Making /boot filesystem : ext2"
    mkfs.ext2 -F -L boot -m 0 -q /dev/${DSK}1 >/dev/null
    echo "==> Making /root filesystem : ${FS}"
    ${MKFS} ${MKFS_L} root /dev/${ROOT_PARTITION} >/dev/null
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        echo "==> Making /home filesystem : ${FS}"
        ${MKFS} ${MKFS_L} home /dev/${DSK}4 >/dev/null
    fi

    if [ "${PARTITION_LAYOUT}" == "bsrh" ] || [ "${PARTITION_LAYOUT}" == "bsr" ]; then
        echo -n "==> "
        mkswap -f -L swap /dev/${DSK}2
        swapon /dev/${DSK}2
    fi

    echo "==> Mounting filesystems"
    mount /dev/${ROOT_PARTITION} ${TARGET_PREFIX} >/dev/null
    mkdir -p ${TARGET_PREFIX}/{boot,home}
    mount /dev/${DSK}1 ${TARGET_PREFIX}/boot >/dev/null
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        mount /dev/${DSK}4 ${TARGET_PREFIX}/home >/dev/null
    fi
fi

# Update and fix pacman keys
echo "==> Updating pacman keys"
pacman-key --refresh-keys >/dev/null 2>&1
echo "==> Enabling key : 182ADEA0"
gpg --homedir /etc/pacman.d/gnupg --edit-key 182ADEA0 enable quit >/dev/null 2>&1

# Base system
if [ "${MACHINE}" == "pc" ]; then
    pacstrap -c ${TARGET_PREFIX} `cat packages-base.txt`
else
    pacman -S --noconfirm --needed `grep -Ev "syslinux" packages-base.txt`
fi

if [ "${MACHINE}" == "pc" ]; then
    # Uncomment the multilib repo on the install ISO and the target
    if [ "${CPU}" == "x86_64" ]; then
        sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
        sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' ${TARGET_PREFIX}/etc/pacman.conf
    fi

    genfstab -t UUID -p ${TARGET_PREFIX} >> ${TARGET_PREFIX}/etc/fstab
fi

# https://wiki.archlinux.org/index.php/Pacman_Tips#Network_shared_pacman_cache
sed -i 's/#CleanMethod = KeepInstalled/CleanMethod = KeepCurrent/' ${TARGET_PREFIX}/etc/pacman.conf

# F2FS does not currently have an `fsck` tool.
if [ "${FS}" == "f2fs" ]; then
    sed -i 's/keyboard fsck/keyboard/' ${TARGET_PREFIX}/etc/mkinitcpio.conf
fi

# Install and configure the extra packages
if [ "${INSTALL_TYPE}" == "desktop" ] || [ "${INSTALL_TYPE}" == "server" ]; then
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
        pacstrap -c ${TARGET_PREFIX} `pacman -Qq | grep -Ev "gcc-libs|grub|gummi|ntp"`
        EXTRA_RET=$?
        pacstrap -c ${TARGET_PREFIX} `cat packages-extra.txt`
        EXTRA_RET=$((${EXTRA_RET} + $?))
    else
        pacman -S --noconfirm --needed `cat packages-core.txt | grep -Ev "pcmciautils|syslinux"`
        EXTRA_RET=$?
        pacman -S --noconfirm --needed `cat packages-extra.txt`
        EXTRA_RET=$((${EXTRA_RET} + $?))
    fi

    if [ ${EXTRA_RET} -ne 0 ]; then
        echo "ERROR! Installing extra packages failed. Try running `basename ${0}` again."
        exit 1
    fi
fi

# Configure mkinitcpio.conf
update_early_hooks consolefont
update_early_hooks keymap

# Add offline discard cron here. None of my SSDs are TRIM compatible.
#  - http://www.webupd8.org/2013/01/enable-trim-on-ssd-solid-state-drives.html
if [ ${ENABLE_DISCARD} -eq 1 ]; then
    addlinetofile "#!/usr/bin/env bash"                  ${TARGET_PREFIX}/etc/cron.daily/trim
    addlinetofile "$(date -R)      >> /var/log/trim.log" ${TARGET_PREFIX}/etc/cron.daily/trim
    addlinetofile "fstrim -v /     >> /var/log/trim.log" ${TARGET_PREFIX}/etc/cron.daily/trim
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        addlinetofile "fstrim -v /home >> /var/log/trim.log" ${TARGET_PREFIX}/etc/cron.daily/trim
    fi
fi

# Start building the configuration script
start_config

# Configure the hostname.
add_config "echo ${FQDN} > /etc/hostname"
add_config "hostnamectl set-hostname --static ${FQDN}"

# Configure timezone and hwclock
add_config "echo ${TIMEZONE} > /etc/timezone"

if [ "${MACHINE}" == "pc" ]; then
    add_config "hwclock --systohc --utc"
else
    add_config "rm /etc/localtime 2>/dev/null"
fi
add_config "ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime"

# Configure console font and keymap
add_config "echo KEYMAP=${KEYMAP}     >  /etc/vconsole.conf"
add_config "echo FONT=${FONT}         >> /etc/vconsole.conf"
add_config "echo FONT_MAP=${FONT_MAP} >> /etc/vconsole.conf"

# Configure locale
add_config "sed -i \"s/#${LANG}/${LANG}/\" /etc/locale.gen"
add_config "echo LANG=${LANG}             >  /etc/locale.conf"
add_config "echo LC_COLLATE=${LC_COLLATE} >> /etc/locale.conf"
add_config "locale-gen"
addlinetofile "export EDITOR=nano" ${TARGET_PREFIX}/etc/profile
echo "blacklist pcspkr" > ${TARGET_PREFIX}/etc/modprobe.d/blacklist-pcspkr.conf

# https://wiki.archlinux.org/index.php/CPU_Frequency_Scaling
modprobe -q acpi-cpufreq
if [ $? -eq 0 ]; then
    echo "acpi-cpufreq" > ${TARGET_PREFIX}/etc/modules-load.d/acpi-cpufreq.conf
else
    modprobe -q powernow_k8
    if [ $? -eq 0 ]; then
        echo "powernow_k8" > ${TARGET_PREFIX}/etc/modules-load.d/powernow_k8.conf
    fi
fi

if [ "${INSTALL_TYPE}" == "desktop" ] || [ "${INSTALL_TYPE}" == "server" ]; then
    # Configure mDNS
    sed -i 's/hosts: files dns/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4/' ${TARGET_PREFIX}/etc/nsswitch.conf
    # Members of the `wheel` group are sudoers.
    sed -i '/%wheel ALL=(ALL) ALL/s/^#//' ${TARGET_PREFIX}/etc/sudoers
    add_config "systemctl start sshdgenkeys.service"
    add_config "systemctl enable sshd.service"
    add_config "systemctl enable openntpd.service"
    if [ "${INSTALL_TYPE}" != "server" ]; then
        add_config "systemctl enable avahi-daemon.service"
        add_config "systemctl enable rpc-statd.service"
    fi

    # Install `packer`.
    if [ "${MACHINE}" == "pc" ]; then
        add_config "wget http://aur.archlinux.org/packages/pa/packer/packer.tar.gz -O /usr/local/src/packer.tar.gz"
        add_config 'if [ $? -ne 0 ]; then'
        add_config "    echo \"ERROR! Couldn't downloading packer.tar.gz. Aborting packer install.\""
        add_config "    exit 1"
        add_config "fi"
        add_config "cd /usr/local/src"
        add_config "tar zxvf packer.tar.gz"
        add_config "cd packer"
        add_config "makepkg --asroot -s --noconfirm"
        add_config 'pacman -U --noconfirm `ls -1t /usr/local/src/packer/*.pkg.tar.xz | head -1`'
    else
        add_config "pacman -S --noconfirm packer"
    fi

    # Install dot files and configure the root user shell.
    rsync -aq skel/ ${TARGET_PREFIX}/etc/skel/
    rsync -aq skel/ ${TARGET_PREFIX}/root/
fi

add_config "systemctl enable cronie.service"
add_config "systemctl enable syslog-ng"

if [ -f netctl ]; then
    cp netctl ${TARGET_PREFIX}/etc/netctl/mynetwork
    add_config "netctl enable mynetwork"
fi

if [ "${INSTALL_TYPE}" == "desktop" ]; then
    if [ "${DE}" != "shell" ]; then
        pacstrap -c ${TARGET_PREFIX} `cat packages-xorg.txt`
        add_config "localectl set-keymap ${KEYMAP}"
        if [ "${DE}" == "xorg" ]; then
            pacstrap -c ${TARGET_PREFIX} `cat packages-xinit.txt`
        elif [ "${DE}" == "gnome" ]; then
            pacstrap -c ${TARGET_PREFIX} `cat packages-gnome.txt packages-gst.txt`
            add_config "systemctl enable gdm.service"
            add_config "systemctl enable accounts-daemon.service"
            add_config "systemctl enable upower.service"
            add_config "systemctl enable NetworkManager.service"
        elif [ "${DE}" == "kde" ]; then
            LOCALE=`echo ${LANG} | cut -d'.' -f1`
            if [ "${LOCALE}" == "pt_BR" ] || [ "${LOCALE}" == "en_GB" ] || [ "${LOCALE}" == "zh_CN" ]; then
                LOCALE_KDE=`echo ${LOCALE} | tr '[:upper:]' '[:lower:]'`
            elif [ "${LOCALE}" == "en_US" ]; then
                LOCALE_KDE="en_gb"
            else
                LOCALE_KDE=`echo ${LOCALE} | cut -d\_ -f1`
            fi
            echo "kde-l10n-${LOCALE_KDE}" >> packages-kde.txt
            pacstrap -c ${TARGET_PREFIX} `cat packages-kde.txt packages-gst.txt`
            add_config "systemctl enable kdm.service"
            add_config "systemctl enable upower.service"
        fi
    fi
fi

if [ -f users.csv ]; then
    IFS=$'\n';
    for USER in `cat users.csv`
    do
        _USERNAME=`echo ${USER} | cut -d',' -f1`
        _PLAINPASSWD=`echo ${USER} | cut -d',' -f2`
        _CRYPTPASSWD=`openssl passwd -crypt ${_PLAINPASSWD}`
        _COMMENT=`echo ${USER} | cut -d',' -f3`
        _EXTRA_GROUPS=`echo ${USER} | cut -d',' -f4`
        if [ "${_EXTRA_GROUPS}" != "" ]; then
            _GROUPS=${BASE_GROUPS},${_EXTRA_GROUPS}
        else
            _GROUPS=${BASE_GROUPS}
        fi
        add_config "useradd --password ${_CRYPTPASSWD} --comment \"${_COMMENT}\" --groups ${_GROUPS} --shell /bin/bash --create-home -g users ${_USERNAME}"
        #add_config "usermod --password ${_CRYPTPASSWD} --comment \"${_COMMENT}\" --groups ${_GROUPS} --shell /bin/bash --create-home -g users --append ${_USERNAME}"
    done
fi

PASSWORD_CRYPT=`openssl passwd -crypt ${PASSWORD}`
add_config "usermod --password ${PASSWORD_CRYPT} root"

if [ "${MACHINE}" == "pc" ]; then
    add_config "mkinitcpio -p linux"
    add_config "syslinux-install_update -iam"
    arch-chroot ${TARGET_PREFIX} /usr/local/bin/arch-config.sh
    cp {splash.png,terminus.psf,syslinux.cfg} ${TARGET_PREFIX}/boot/syslinux/
else
    /usr/local/bin/arch-config.sh
fi

swapoff -a && sync
if [ -n "${NFS_CACHE}" ]; then
    addlinetofile "${NFS_CACHE} /var/cache/pacman/pkg nfs defaults,noauto,x-systemd.automount 0 0" ${TARGET_PREFIX}/etc/fstab
    if [ "${MACHINE}" == "pc" ]; then
        umount -fv /var/cache/pacman/pkg
    fi
fi

if [ "${MACHINE}" == "pc" ]; then
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        umount -fv ${TARGET_PREFIX}/home
    fi
    umount -fv ${TARGET_PREFIX}/{boot,}
fi

echo "All done!"
