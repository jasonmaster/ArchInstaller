#!/usr/bin/env bash

#TODO
# - Consolidate the partitioning.
# - Add option to enable NFS client
# - Make dot files optional, like users.csv.

DSK=""
FQDN="arch.example.org"
TIMEZONE="Europe/London"
KEYMAP="uk"
LANG="en_GB.UTF-8"
PASSWORD=""
FS="xfs" #or ext4 are the only supported options right now.
PARTITION_TYPE="msdos"
PARTITION_LAYOUT=""

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
    echo "  -f : The filesystem to use. Currently 'ext4' and 'xfs' are supported, defaults to '${FS}'."
    echo "  -k : The keyboard mapping to use. Defaults to '${KEYMAP}'. See '/usr/share/kbd/keymaps/' for options."            
    echo "  -l : The language to use. Defaults to '${LANG}'. See '/etc/locale.gen' for options."        
    echo "  -n : The hostname to use. Defaults to '${FQDN}'"            
    echo "  -t : The timezone to use. Defaults to '${TIMEZONE}'. See '/usr/share/zoneinfo/' for options."    
    echo
    echo "User provisioning"
    echo
    echo "Optionally you can create a file that defines user accounts that should be provisioned."
    echo "The format is:"
    echo
    echo "username,password,comment,groups"
    echo
    echo "In the examples below, 'fred' is a sudo'er but 'barney' is not."
    echo
    echo "fred,fl1nt5t0n3,\"Fred Flintstone\",wheel"
    echo "barney,ru88l3,\"Barney Rubble\","    
    exit 1
}

OPTSTRING=b:d:f:hk:l:n:p:t:w:
while getopts ${OPTSTRING} OPT
do
    case ${OPT} in
        b) PARTITION_TYPE=${OPTARG};;
        d) DSK=${OPTARG};;
        f) FS=${OPTARG};;
        h) usage;;
        k) KEYMAP=${OPTARG};;
        l) LANG=${OPTARG};;
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
    usage
fi

if [ "${FS}" != "ext4" ] && [ "${FS}" != "xfs" ]; then
    echo "ERROR! Filesystem ${FS} is not supported."
    usage
fi

if [ "${PARTITION_TYPE}" != "msdos" ] && [ "${PARTITION_TYPE}" != "gpt" ]; then
    echo "ERROR! Partition type ${PARTITION_TYPE} is not supported."
fi

if [ -z "${PASSWORD}" ]; then
    echo "ERROR! The 'root' password has not been set."
    usage
fi

if [ "${PARTITION_LAYOUT}" != "bsrh" ] && [ "${PARTITION_LAYOUT}" != "bsr" ] && [ "${PARTITION_LAYOUT}" != "br" ]; then
    echo "ERROR! I don't know what to do with '${PARTITION_LAYOUT}' partition layout."
    usage
fi

if [ ! -f /usr/share/zoneinfo/${TIMEZONE} ]; then
    echo "ERROR! I can't find the zone info for '${TIMEZONE}'."
    usage
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
rmmod -s pcspkr

# Calcualte a sane size for swap. Half RAM.
SWP=`awk '/MemTotal/ {printf( "%.0f\n", $2 / 1000 / 2 )}' /proc/meminfo`

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
    root=$(( $boot + (1024*24) ))
    swap=$(( $root + ${SWP} ))
    max=$(( $(cat /sys/block/sda/size) * 512 / 1024 / 1024 - 1 ))

    parted /dev/${DSK} unit MiB mkpart primary     1 $boot
    parted /dev/${DSK} unit MiB mkpart primary $boot $root
    parted /dev/${DSK} unit MiB mkpart primary $root $swap
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
    parted /dev/${DSK} unit MiB mkpart primary $boot $swap
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

# Base system
pacstrap /mnt base base-devel openssh sudo syslinux wget

# Configure the system
sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /mnt/etc/sudoers
genfstab -p /mnt >> /mnt/etc/fstab
echo "${FQDN}" > /mnt/etc/hostname
echo "${TIMEZONE}" > /mnt/etc/timezone

# Prevent unwanted cache purges
#  - https://wiki.archlinux.org/index.php/Pacman_Tips#Network_shared_pacman_cache
sed -i 's/#CleanMethod = KeepInstalled/CleanMethod = KeepCurrent/' /mnt/etc/pacman.conf

# Configure console and keymap
echo KEYMAP=${KEYMAP}        >  /mnt/etc/vconsole.conf
echo FONT=iso01.16           >> /mnt/etc/vconsole.conf
#echo FONT_MAP=8859-1_to_uni >> /mnt/etc/vconsole.conf

# Configure locale
sed -i "s/#${LANG}/${LANG}/" /mnt/etc/locale.gen
echo LANG=${LANG}   >   /mnt/etc/locale.conf
echo LC_COLLATE=C   >>  /mnt/etc/locale.conf
#echo LANG=en_GB.utf8  >>  /mnt/etc/environment # NOT SURE IF REQUIRED

# Configure SYSLINUX
wget http://projects.archlinux.org/archiso.git/plain/configs/releng/syslinux/splash.png -O /mnt/boot/syslinux/splash.png
sed -i 's/UI menu.c32/#UI menu.c32/' /mnt/boot/syslinux/syslinux.cfg
sed -i 's/#UI vesamenu.c32/UI vesamenu.c32/' /mnt/boot/syslinux/syslinux.cfg
sed -i 's/#MENU BACKGROUND/MENU BACKGROUND/' /mnt/boot/syslinux/syslinux.cfg
# Correct the root parition configuration
sed -i "s/sda3/${ROOT_PARTITION}/g" /mnt/boot/syslinux/syslinux.cfg
    
# Configure 'nano' as the system default
echo "export EDITOR=nano" >> /mnt/etc/profile
sed -i 's/# set const/set const/' /etc/nanorc
sed -i 's/# set morespace/set morespace/' /etc/nanorc
sed -i 's/# set nowrap/set nowrap/' /etc/nanorc
sed -i 's/# set smarthome/set smarthome/' /etc/nanorc
sed -i 's/# set tabsize 8/set tabsize 4/' /etc/nanorc
sed -i 's/# set tabstospaces/set tabstospaces/' /etc/nanorc    

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
    
# Enter the chroot and complete the install by adding `systemd` and `packer`
# - pacman -S systemd systemd-sysvcompat systemd-arch-units # recently removed
cat >/mnt/usr/local/bin/installer.sh<<'ENDOFSCRIPT'
#!/bin/bash
pacman -Syy
wget https://aur.archlinux.org/packages/pa/packer/packer.tar.gz -O /usr/local/src/packer.tar.gz   
cd /usr/local/src
tar zxvf packer.tar.gz
cd packer
makepkg --asroot -s --noconfirm
pacman -U --noconfirm `ls -1t /usr/local/src/packer/*.pkg.tar.xz | head -1`
echo "Y
Y
Y
" | pacman -S --noconfirm --needed bash-completion ddrescue dkms lsb-release rsync screen tree
pacman -S --noconfirm --needed colordiff lesspipe source-highlight
pacman -S --noconfirm --needed arj cabextract lzop p7zip rpmextract sharutils unace unrar unzip uudeview xz zip
pacman -S --noconfirm --needed bzr cvs git mercurial subversion python2-paramiko
pacman -S --noconfirm --needed abs devtools namcap
pacman -S --noconfirm --needed cifs-utils dosfstools nfs-utils ntfsprogs
pacman -S --noconfirm --needed dialog wpa_supplicant ipw2100-fw ipw-2200-fw
pacman -S --noconfirm --needed ethtool powertop
pacman -S --noconfirm --needed avahi dbus nss-mdns chrony
sed -i 's/hosts: files dns/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4/' /etc/nsswitch.conf
sed -i 's/! server ntp.public-server.org/server uk.pool.ntp.org/' /etc/chrony.conf
#replaceinfile 'NEED_STATD=""' 'NEED_STATD="YES"' /etc/conf.d/nfs-common.conf
ENDOFSCRIPT
chmod +x /mnt/usr/local/bin/installer.sh
arch-chroot /mnt /usr/local/bin/installer.sh
arch-chroot /mnt ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
arch-chroot /mnt locale-gen
arch-chroot /mnt mkinitcpio -p linux
arch-chroot /mnt /usr/sbin/syslinux-install_update -iam
arch-chroot /mnt systemctl start sshdgenkeys.service
arch-chroot /mnt systemctl enable cronie.service
arch-chroot /mnt systemctl enable chrony.service
arch-chroot /mnt systemctl enable avahi-daemon.service
arch-chroot /mnt systemctl enable sshd.service
arch-chroot /mnt systemctl enable rpc-statd.service

# Grab my dot files.
git clone https://github.com/flexiondotorg/dot-files.git /tmp/dot-files

# Create users and configure bash, if there a users file.
if [ -f users.csv ]; then
    IFS=$'\n';
    for USER in `cat users.csv`
    do
        _USERNAME=`echo ${USER} | cut -d',' -f1`
        _PLAINPASSWD=`echo ${USER} | cut -d',' -f2`
        _CRYPTPASSWD=`openssl passwd -crypt ${_PLAINPASSWD}`
        _COMMENT=`echo ${USER} | cut -d',' -f3`
        _EXTRA_GROUPS=`echo ${USER} | cut -d',' -f4`
        _BASIC_GROUPS="adm,audio,disk,lp,optical,storage,video,games,power,scanner"
        if [ "${_EXTRA_GROUPS}" != "" ]; then
            _GROUPS=${_BASIC_GROUPS},${_EXTRA_GROUPS}
        else
            _GROUPS=${_BASIC_GROUPS}
        fi    
        arch-chroot /mnt useradd --password ${_CRYPTPASSWD} --comment "${_COMMENT}" --groups ${_GROUPS} --shell /bin/bash --create-home -g users ${_USERNAME}
        cp /tmp/dot-files/dot-bashrc /mnt/home/${_USERNAME}/.bashrc
        cp /tmp/dot-files/dot-bash_logout /mnt/home/${_USERNAME}/.bash_logout       
        arch-chroot /mnt chown -R ${_USERNAME}:users /home/${_USERNAME}
    done
fi

# Change root password and configre bash.
PASSWORD_CRYPT=`openssl passwd -crypt ${PASSWORD}`
arch-chroot /mnt usermod --password ${PASSWORD_CRYPT} root
cp /tmp/dot-files/dot-bashrc /mnt/root/.bashrc
cp /tmp/dot-files/dot-bash_logout /mnt/root/.bash_logout

# Unmount
sync
if [ "${PARTITION_LAYOUT}" == "bsrh" ]; then    
    umount /mnt/home
fi
umount /mnt/{boot,}
