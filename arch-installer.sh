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
LOCALE=`echo ${LANG} | cut -d'.' -f1`
LC_COLLATE="C"
FONT_MAP="8859-1_to_uni"
PASSWORD=""
FS="ext4"
PACKAGES="packages/base/packages-base.txt"
PARTITION_TYPE="msdos"
PARTITION_LAYOUT=""
INSTALL_TYPE="desktop"
TARGET_PREFIX="/mnt"
CPU=`uname -m`
DE="none"

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
    if [ "${HOSTANME}" == "archiso" ]; then
        echo "  ${0} -d sda -p bsrh -w P@ssw0rd -b ${PARTITION_TYPE} -f ${FS} -k ${KEYMAP} -l ${LANG} -n ${FQDN} -t ${TIMEZONE}"
    else
        echo "  ${0} -w P@ssw0rd -k ${KEYMAP} -l ${LANG} -n ${FQDN} -t ${TIMEZONE}"
    fi
    echo
    echo "Required parameters"
    if [ "${HOSTNAME}" == "archiso" ]; then
        echo "  -d : The target device. For example, 'sda'."
        echo "  -p : The partition layout to use. One of: "
        echo "         'bsrh' : /boot, swap, /root and /home"
        echo "         'bsr'  : /boot, swap and /root"
        echo "         'br'   : /boot and /root, no swap."
    fi
    echo "  -w : The root password."
    echo
    echo "Optional parameters"
    if [ "${HOSTNAME}" == "archiso" ]; then
        echo "  -b : The partition type to use. Defaults to '${PARTITION_TYPE}'. Can be 'msdos' or 'gpt'."
        echo "  -f : The filesystem to use. 'bfs', 'btrfs', 'ext{2,3,4}', 'f2fs, 'jfs', 'nilfs2', 'ntfs', 'reiserfs' and 'xfs' are supported. Defaults to '${FS}'."
    fi
    echo "  -c : The NFS export to mount and use as the pacman cache."
    echo "  -e : The desktop environment to install. Defaults to '${DE}'. Can be 'none', 'cinnamon', 'gnome', 'kde', 'lxde', 'mate' or 'xfce'"
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

if [ "${HOSTNAME}" == "archiso" ]; then

    # Look for the VirtualBox Guest Service and add additional package and groups if required.
    VBOX_GUEST=`lspci -d 80ee:cafe`

    if [ ! -b /dev/${DSK} ]; then
        echo "ERROR! Target install disk not found."
        echo " - See `basename ${0}` -h"
        exit 1
    fi

    if [ `cat /sys/block/${DSK}/queue/rotational` == "0" ] && [ `cat /sys/block/${DSK}/removable` == "0" ]; then
        if [ -n "$(hdparm -I /dev/${DSK} 2>&1 | grep 'TRIM supported')" ]; then
            HAS_TRIM=1
            HAS_SSD=1
        else
            HAS_TRIM=0
            HAS_SSD=1
        fi
    else
        HAS_TRIM=0
        HAS_SSD=0
    fi

    MOUNT_OPTS="-o relatime"
    if [ ${HAS_SSD} -eq 1 ]; then
        # From `man mount` - In case of media with limited number of write cycles
        # (e.g. some flash drives) "sync" may cause life-cycle shortening.
        # Therefore use `async` on SSDs.
        # http://www.blah-blah.ch/it/general/filesystem-performance-ssd/
        MOUNT_OPTS="${MOUNT_OPTS},async"
    fi
    MKFS_L="-L"

    # TRIM is currently only supported on `btrfs`, `ext3`, `ext4`, `jfs` and `xfs`.
    # So, disable `fstrim` on filesystems that don't support TRIM, even if the hardware does.
    case ${FS} in
        "bfs")      MKFS="mkfs.bfs"
                    MKFS_L="-V"
                    HAS_TRIM=0
                    ;;
        "btrfs")    MKFS="mkfs.btrfs -f"
                    MOUNT_OPTS="${MOUNT_OPTS},compress=lzo"
                    if [ ${HAS_SSD} -eq 1 ]; then
                        MOUNT_OPTS="${MOUNT_OPTS},ssd"
                    fi
                    ;;
        "ext2")     MKFS="mkfs.ext2 -F -m 0 -q"
                    HAS_TRIM=0
                    ;;
        "ext3")     MKFS="mkfs.ext3 -F -m 0 -q";;
        "ext4")     MKFS="mkfs.ext4 -F -m 0 -q";;
        "f2fs")     MKFS="mkfs.f2fs"
                    MKFS_L="-l"
                    HAS_TRIM=0
                    ;;
        "jfs")      MKFS="mkfs.jfs -q";;
        "nilfs2")   MKFS="mkfs.nilfs2 -q"
                    HAS_TRIM=0;;
        "ntfs")     MKFS="mkfs.ntfs -q"
                    HAS_TRIM=0;;
        "reiserfs") MKFS="mkfs.reiserfs --format 3.6 -f -q"
                    MKFS_L="-l"
                    HAS_TRIM=0
                    ;;
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

if [ "${DE}" != "none" ] && [ "${DE}" != "cinnamon" ] && [ "${DE}" != "gnome" ] && [ "${DE}" != "kde" ] && [ "${DE}" != "lxde" ] && [ "${DE}" != "mate" ] && [ "${DE}" != "xfce" ]; then
    echo "ERROR! '${DE}' is not a supported desktop environment."
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
if [ "${HOSTNAME}" == "archiso" ]; then
    echo " - Installation target : /dev/${DSK}"
    if [ ${HAS_SSD} -eq 1 ]; then
        if [ ${HAS_TRIM} -eq 1 ]; then
            echo " - Disk type           : Solid state with TRIM."
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

loadkeys -q ${KEYMAP}

echo
if [ "${HOSTNAME}" == "archiso" ]; then
    echo "WARNING: `basename ${0}` is about to destroy everything on /dev/${DSK}!"
else
    echo "WARNING: `basename ${0}` is about to start installing!"
fi
echo "I make no guarantee that the installation of Arch Linux will succeed."
echo "Press RETURN to try your luck or CTRL-C to cancel."
read

# Install dmidecode and determine the current (not running) Kernel version
pacman -Syy --noconfirm --needed dmidecode
KERNEL_VER=`pacman -Si linux | grep Version | cut -d':' -f2 | sed 's/ //g'`

if [ "${HOSTNAME}" == "archiso" ]; then
    echo "==> Clearing partition table on /dev/${DSK}"
    sgdisk --zap /dev/${DSK} >/dev/null 2>&1
    echo "==> Destroying magic strings and signatures on /dev/${DSK}"
    dd if=/dev/zero of=/dev/${DSK} bs=512 count=2048 >/dev/null 2>&1
    wipefs -a /dev/${DSK} 2>/dev/null
    echo "==> Initialising disk /dev/${DSK}: ${PARTITION_TYPE}"
    parted -s /dev/${DSK} mktable ${PARTITION_TYPE} >/dev/null

    # Calculate common partition sizes.
    swap_size=`awk '/MemTotal/ {printf( "%.0f\n", $2 / 1000 )}' /proc/meminfo`
    boot_end=$(( 1 + 122 ))
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
    mount ${MOUNT_OPTS} /dev/${ROOT_PARTITION} ${TARGET_PREFIX} >/dev/null
    mkdir -p ${TARGET_PREFIX}/{boot,home}
    mount /dev/${DSK}1 ${TARGET_PREFIX}/boot >/dev/null
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        mount ${MOUNT_OPTS} /dev/${DSK}4 ${TARGET_PREFIX}/home >/dev/null
    fi
fi

# Update and fix pacman keys
echo "==> Updating pacman keys"
pacman-key --refresh-keys >/dev/null 2>&1
echo "==> Enabling key : 182ADEA0"
gpg --homedir /etc/pacman.d/gnupg --edit-key 182ADEA0 enable quit >/dev/null 2>&1

# Chain packages
if [ -n "${VBOX_GUEST}" ]; then
    PACKAGES="${PACKAGES} packages/base/packages-virtualbox-guest.txt"
    VBOX_GROUP=",vboxsf"
else
    VBOX_GROUP=""
fi
if [ "${INSTALL_TYPE}" != "minimal" ]; then
    PACKAGES="${PACKAGES} packages/base/packages-archiso.txt packages/base/packages-extra.txt"
    if [ "${DE}" != "none" ] && [ "${INSTALL_TYPE}" == "desktop" ]; then
        if [ "${DE}" == "kde" ]; then
            if [ "${LOCALE}" == "pt_BR" ] || [ "${LOCALE}" == "en_GB" ] || [ "${LOCALE}" == "zh_CN" ]; then
                LOCALE_KDE=`echo ${LOCALE} | tr '[:upper:]' '[:lower:]'`
            elif [ "${LOCALE}" == "en_US" ]; then
                LOCALE_KDE="en_gb"
            else
                LOCALE_KDE=`echo ${LOCALE} | cut -d\_ -f1`
            fi
            echo "kde-l10n-${LOCALE_KDE}" >> packages/desktop/packages-kde.txt
        elif [ "${DE}" == "mate" ]; then
            echo -e '\n[mate]\nSigLevel = Optional TrustAll\nServer = http://repo.mate-desktop.org/archlinux/$arch' >> /etc/pacman.conf
        fi
        PACKAGES="${PACKAGES} packages/desktop/packages-xorg.txt packages/desktop/packages-${DE}.txt packages/desktop/packages-gst.txt packages/desktop/packages-cups.txt packages/desktop/packages-ttf.txt"
    fi
fi

# Install packages
if [ "${HOSTNAME}" == "archiso" ]; then
    pacstrap -c ${TARGET_PREFIX} `cat ${PACKAGES} | grep -Ev "darkhttpd|grub|gummi|irssi|nmap|^ntp"`
    if [ $? -ne 0 ]; then
        echo "ERROR! 'pacstrap' failed. Cleaning up and exitting."
        swapoff -a
        if [ -n "${NFS_CACHE}" ]; then
            umount -fv /var/cache/pacman/pkg
        fi
        if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
            umount -fv ${TARGET_PREFIX}/home
        fi
        umount -fv ${TARGET_PREFIX}/{boot,}
        exit 1
    fi
    genfstab -t UUID -p ${TARGET_PREFIX} >> ${TARGET_PREFIX}/etc/fstab
    # Only install multilib on workstations, I have no need for it on my Arch "servers".
    if [ "${INSTALL_TYPE}" == "desktop" ] && [ "${CPU}" == "x86_64" ]; then
        sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
        sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' ${TARGET_PREFIX}/etc/pacman.conf
        echo -en "\nY\nY\nY\nY\nY\n" | pacstrap -c -i ${TARGET_PREFIX} multilib-devel
    fi
else
    pacman -S --noconfirm --needed `cat ${PACKAGES} | grep -Ev "darkhttpd|grub|gummi|irssi|nmap|^ntp|pcmciautils|syslinux"`
fi

# Start building the configuration script
start_config

if [ "${HOSTNAME}" == "archiso" ]; then
    add_config "depmod -a ${KERNEL_VER}-ARCH"
    add_config "mkinitcpio -p linux"
    add_config "hwclock --systohc --utc"
else
    add_config "rm /etc/localtime 2>/dev/null"
fi
add_config "ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime"

# Configure the hostname.
add_config "echo ${FQDN} > /etc/hostname"
add_config "hostnamectl set-hostname --static ${FQDN}"

# Configure timezone and hwclock
add_config "echo ${TIMEZONE} > /etc/timezone"

# Configure vconsole and locale
update_early_hooks keymap

# Font and font map
if [ "${INSTALL_TYPE}" != "minimal" ]; then
    FONT="ter-116b"
    update_early_hooks consolefont
else
    FONT=""
fi
add_config "echo KEYMAP=${KEYMAP}      > /etc/vconsole.conf"
add_config "echo FONT=${FONT}         >> /etc/vconsole.conf"
add_config "echo FONT_MAP=${FONT_MAP} >> /etc/vconsole.conf"
add_config "sed -i \"s/#${LANG}/${LANG}/\" /etc/locale.gen"
add_config "echo LANG=${LANG}             >  /etc/locale.conf"
add_config "echo LC_COLLATE=${LC_COLLATE} >> /etc/locale.conf"
add_config "locale-gen"
add_config 'echo "export EDITOR=nano" >> /etc/profile'

# https://wiki.archlinux.org/index.php/Pacman_Tips#Network_shared_pacman_cache
add_config "sed -i 's/#CleanMethod = KeepInstalled/CleanMethod = KeepCurrent/' /etc/pacman.conf"
add_config "sed -i 's/#Color/Color/' /etc/pacman.conf"

# F2FS does not currently have a `fsck` tool.
if [ "${FS}" == "f2fs" ]; then
    add_config "sed -i 's/keyboard fsck/keyboard/' /etc/mkinitcpio.conf"
fi

# Add `fstrim` cron job here.
#  - https://patrick-nagel.net/blog/archives/337
#  - http://blog.neutrino.es/2013/howto-properly-activate-trim-for-your-ssd-on-linux-fstrim-lvm-and-dmcrypt/
if [ ${HAS_TRIM} -eq 1 ]; then
    add_config 'echo "#!/usr/bin/env bash"                  >  /etc/cron.daily/trim'
    add_config 'echo "$(date -R)  >> /var/log/trim.log"     >> /etc/cron.daily/trim'
    add_config 'echo "fstrim -v / >> /var/log/trim.log"     >> /etc/cron.daily/trim'
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        add_config 'echo "fstrim -v /home >> /var/log/trim.log" >> /etc/cron.daily/trim'
    fi
fi

# By default the maximum number of watches is set to 8192, which is rather low.
# Increasing this value will have no noticeable side effects and ensure things like
# Dropbox and MiniDLNA will work correctly regardless of filesystem.
add_config 'echo "fs.inotify.max_user_watches = 131072" >> /etc/sysctl.conf'

if [ -f netctl ]; then
    cp netctl ${TARGET_PREFIX}/etc/netctl/mynetwork
    add_config "netctl enable mynetwork"
fi

if [ "${INSTALL_TYPE}" == "desktop" ]; then
    if [ "${DE}" == "cinnamon" ]; then
        add_config "systemctl enable lightdm.service"
        add_config "systemctl enable upower.service"
        add_config "systemctl enable accounts-daemon.service"
        add_config "systemctl enable NetworkManager.service"
        add_config "systemctl enable cups.service"
    elif [ "${DE}" == "gnome" ]; then
        add_config "systemctl enable gdm.service"
        add_config "systemctl enable upower.service"
        add_config "systemctl enable accounts-daemon.service"
        add_config "systemctl enable NetworkManager.service"
        add_config "systemctl enable cups.service"
    elif [ "${DE}" == "kde" ]; then
        add_config "systemctl enable kdm.service"
        add_config "systemctl enable upower.service"
        add_config "systemctl enable NetworkManager.service"
        add_config "systemctl enable cups.service"
    elif [ "${DE}" == "lxde" ]; then
        add_config "systemctl enable lxdm.service"
        add_config "systemctl enable upower.service"
        add_config "systemctl enable NetworkManager.service"
        add_config "systemctl enable cups.service"
    elif [ "${DE}" == "mate" ]; then
        echo -e '\n[mate]\nSigLevel = Optional TrustAll\nServer = http://repo.mate-desktop.org/archlinux/$arch' >> ${TARGET_PREFIX}/etc/pacman.conf
        add_config "systemctl enable lightdm.service"
        add_config "systemctl enable upower.service"
        add_config "systemctl enable accounts-daemon.service"
        add_config "systemctl enable NetworkManager.service"
        add_config "systemctl enable cups.service"
    elif [ "${DE}" == "xfce" ]; then
        add_config "systemctl enable lightdm.service"
        add_config "systemctl enable upower.service"
        add_config "systemctl enable NetworkManager.service"
        add_config "systemctl enable cups.service"
    fi
fi

if [ -n "${VBOX_GUEST}" ]; then
    add_config "systemctl enable vboxservice.service"
    add_config "echo 'vboxguest' >  /etc/modules-load.d/virtualbox-guest.conf"
    add_config "echo 'vboxsf'    >> /etc/modules-load.d/virtualbox-guest.conf"
    add_config "echo 'vboxvideo' >> /etc/modules-load.d/virtualbox-guest.conf"
else
    add_config "systemctl enable openntpd.service"
fi

if [ "${INSTALL_TYPE}" == "desktop" ] || [ "${INSTALL_TYPE}" == "server" ]; then
    add_config "sed -i 's/hosts: files dns/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4/' /etc/nsswitch.conf"
    add_config "sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers"
    add_config "systemctl start sshdgenkeys.service"
    add_config "systemctl enable sshd.service"
    add_config "systemctl enable syslog-ng.service"
    add_config "systemctl enable cronie.service"

    if [ "${INSTALL_TYPE}" == "desktop" ]; then
        add_config "systemctl enable avahi-daemon.service"
        add_config "systemctl enable rpc-statd.service"
    fi

    if [ "${HOSTNAME}" == "archiso" ]; then
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
        add_config "packer -S --noconfirm --noedit tlp"
        add_config "systemctl enable tlp"
        # Some SATA chipsets can corrupt data when ALPM is enabled. Disable it
        add_config "sed -i 's/SATA_LINKPWR/#SATA_LINKPWR/' /etc/default/tlp"
    else
        add_config "pacman -S --noconfirm packer"
    fi

    # Install dot files.
    rsync -aq skel/ ${TARGET_PREFIX}/etc/skel/
    rsync -aq skel/ ${TARGET_PREFIX}/root/

    # Configure the hardware
    add_config "echo 'blacklist pcspkr' > /etc/modprobe.d/blacklist-pcspkr.conf"

    # https://wiki.archlinux.org/index.php/CPU_Frequency_Scaling
    modprobe -q acpi-cpufreq
    if [ $? -eq 0 ]; then
        add_config "echo 'acpi-cpufreq' > /etc/modules-load.d/acpi-cpufreq.conf"
    else
        modprobe -q powernow_k8
        if [ $? -eq 0 ]; then
            add_config "echo 'powernow_k8' > /etc/modules-load.d/powernow_k8.conf"
        fi
    fi

    # Configure PCI/USB device specific stuff
    for BUS in pci usb
    do
        if [ "${BUS}" == "pci" ]; then
            DEVICE_FINDER="lspci"
        elif [ "${BUS}" == "usb" ]; then
            DEVICE_FINDER="lsusb"
        fi

        # Make sure the bus works.
        # For example, it is possible USB may not be available on virtualised hosts.
        BUS_TEST=`${DEVICE_FINDER} 2>/dev/null`
        BUS_WORKS=$?

        if [ ${BUS_WORKS} -eq 0 ]; then
            for DEVICE_CONFIG in hardware/${BUS}/*.sh
            do
                if [ -x ${DEVICE_CONFIG} ]; then
                    DEVICE_ID=`echo ${DEVICE_CONFIG} | cut -f3 -d'/' | sed s'/\.sh//'`
                    FOUND_DEVICE=`${DEVICE_FINDER} -d ${DEVICE_ID}`
                    if [ -n "${FOUND_DEVICE}" ]; then
                        # Add the hardware script to the configuration script.
                        echo -e "\n#${DEVICE_ID}\n" >>${TARGET_PREFIX}/usr/local/bin/arch-config.sh
                        grep -Ev "#!" ${DEVICE_CONFIG} >> ${TARGET_PREFIX}/usr/local/bin/arch-config.sh
                    fi
                fi
            done
        fi
    done

    # Configure any system specific stuff
    for IDENTITY in Product_Name Version Serial_Number UUID SKU_Number
    do
        FIELD=`echo ${IDENTITY} | sed 's/_/ /g'`
        VALUE=`dmidecode --type system | grep "${FIELD}" | cut -f2 -d':' | sed s'/^ //' | sed s'/ $//' | sed 's/ /_/g'`
        if [ -x hardware/system/${IDENTITY}/${VALUE}.sh ]; then
            # Add the hardware script to the configuration script.
            echo -e "\n#${IDENTITY} - ${VALUE}\n" >>${TARGET_PREFIX}/usr/local/bin/arch-config.sh
            grep -Ev "#!" hardware/system/${IDENTITY}/${VALUE}.sh >> ${TARGET_PREFIX}/usr/local/bin/arch-config.sh
        fi
    done
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
            _GROUPS=${BASE_GROUPS},${_EXTRA_GROUPS}${VBOX_GROUP}
        else
            _GROUPS=${BASE_GROUPS}${VBOX_GROUP}
        fi
        add_config "useradd --password ${_CRYPTPASSWD} --comment \"${_COMMENT}\" --groups ${_GROUPS} --shell /bin/bash --create-home -g users ${_USERNAME}"
    done
fi

PASSWORD_CRYPT=`openssl passwd -crypt ${PASSWORD}`
add_config "usermod --password ${PASSWORD_CRYPT} root"

if [ "${HOSTNAME}" == "archiso" ]; then
    add_config "syslinux-install_update -iam"
    arch-chroot ${TARGET_PREFIX} /usr/local/bin/arch-config.sh
    cp {splash.png,terminus.psf,syslinux.cfg} ${TARGET_PREFIX}/boot/syslinux/
else
    /usr/local/bin/arch-config.sh
fi

swapoff -a && sync
if [ -n "${NFS_CACHE}" ]; then
    addlinetofile "${NFS_CACHE} /var/cache/pacman/pkg nfs defaults,relatime,noauto,x-systemd.automount,x-systemd.device-timeout=5s 0 0" ${TARGET_PREFIX}/etc/fstab
    if [ "${HOSTNAME}" == "archiso" ]; then
        umount -fv /var/cache/pacman/pkg
    fi
fi

if [ "${HOSTNAME}" == "archiso" ]; then
    if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then
        umount -fv ${TARGET_PREFIX}/home
    fi
    umount -fv ${TARGET_PREFIX}/{boot,}
fi

echo "All done!"
