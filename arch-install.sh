#!/usr/bin/env bash

if [ -f common.sh ]; then
    source common.sh
else
    echo "ERROR! Could not source 'common.sh'"
    exit 1
fi

BASE_GROUPS="adm,audio,disk,lp,optical,storage,video,games,power,scanner,uucp"
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
PARTITION_TYPE="msdos"
PARTITION_LAYOUT=""
INSTALL_TYPE="desktop"
TARGET_PREFIX="/mnt"
CPU=`uname -m`
DE="none"
HAS_TRIM=0
HAS_SSD=0

if [ "${HOSTNAME}" == "archiso" ]; then
    MODE="install"
    BASE_ARCH="x86"
else
    MODE="update"    
    if [ "${CPU}" == "armv6l" ] || [ "${CPU}" == "armv7l" ]; then
        DSK="mmcblk0"
        TARGET_PREFIX=""
        BASE_ARCH="arm"
    elif [ "${CPU}" == "i686" ] || [ "${CPU}" == "x86_64" ]; then
        DSK="sda" #FIXME
        TARGET_PREFIX=""
        BASE_ARCH="x86"
    fi
fi

function usage() {
    echo
    echo "Usage"
    if [ "${MODE}" == "install" ]; then
        echo "  ${0} -d sda -p brh -w P@ssw0rd -b ${PARTITION_TYPE} -f ${FS} -k ${KEYMAP} -l ${LANG} -n ${FQDN} -t ${TIMEZONE}"
    else
        echo "  ${0} -w P@ssw0rd -k ${KEYMAP} -l ${LANG} -n ${FQDN} -t ${TIMEZONE}"
    fi
    echo
    echo "Required parameters"
    if [ "${MODE}" == "install" ]; then
        echo "  -d : The target device. For example, 'sda'."
        echo "  -p : The partition layout to use. One of: "
        echo "         'brh' : /boot, /root and /home"
        echo "         'br'   : /boot and /root."
		echo "  -w : The root password."        
    fi

    echo
    echo "Optional parameters"
    if [ "${MODE}" == "update" ]; then
		echo "  -w : The root password."
	else
        echo "  -b : The partition type to use. Defaults to '${PARTITION_TYPE}'. Can be 'msdos' or 'gpt'."
        echo "  -f : The filesystem to use. 'bfs', 'btrfs', 'ext{2,3,4}', 'f2fs, 'jfs', 'nilfs2', 'ntfs', 'reiserfs' and 'xfs' are supported. Defaults to '${FS}'."
    fi
    echo "  -c : The NFS export to mount and use as the pacman cache."
    echo "  -e : The desktop environment to install. Defaults to '${DE}'. Can be 'none', 'cinnamon', 'gnome', 'kde', 'lxde', 'mate' or 'xfce'"
    echo "  -k : The keyboard mapping to use. Defaults to '${KEYMAP}'. See '/usr/share/kbd/keymaps/' for options."
    echo "  -l : The language to use. Defaults to '${LANG}'. See '/etc/locale.gen' for options."
    echo "  -n : The hostname to use. Defaults to '${FQDN}'"
    echo "  -r : The computer role. Defaults to '${INSTALL_TYPE}'. Can be 'desktop' or 'server'."
    echo "  -t : The timezone to use. Defaults to '${TIMEZONE}'. See '/usr/share/zoneinfo/' for options."
    echo
    echo "User provisioning"
    echo
    echo "Optionally you can create a file that defines user accounts that should be provisioned."
    echo "The format is:"
    echo
    echo "username,password,comment,extra_groups"
    echo
    echo "All users are added to the following groups:"
    echo
    echo " - ${BASE_GROUPS}"
    echo
    exit 1
}

function query_disk_subsystem() {
	if [ "${MODE}" == "install" ]; then
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
						HAS_TRIM=0;;
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

		if [ "${PARTITION_LAYOUT}" != "brh" ] && [ "${PARTITION_LAYOUT}" != "br" ]; then
			echo "ERROR! I don't know what to do with '${PARTITION_LAYOUT}' partition layout."
			echo " - See `basename ${0}` -h"
			exit 1
		fi
	fi
}

function test_nfs_cache() {
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
}

function summary() {
	echo
	echo "Installation Summary"
	echo
	if [ "${MODE}" == "install" ]; then
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
	if [ "${MODE}" == "install" ]; then
		echo "WARNING: `basename ${0}` is about to destroy everything on /dev/${DSK}!"
	else
		echo "WARNING: `basename ${0}` is about to start installing!"
	fi
	echo "I make no guarantee that the installation of Arch Linux will succeed."
	echo "Press RETURN to try your luck or CTRL-C to cancel."
	read
}

function format_disks() {
    echo "==> Clearing partition table on /dev/${DSK}"
    sgdisk --zap /dev/${DSK} >/dev/null 2>&1
    echo "==> Destroying magic strings and signatures on /dev/${DSK}"
    dd if=/dev/zero of=/dev/${DSK} bs=512 count=2048 >/dev/null 2>&1
    wipefs -a /dev/${DSK} 2>/dev/null
    echo "==> Initialising disk /dev/${DSK}: ${PARTITION_TYPE}"
    parted -s /dev/${DSK} mktable ${PARTITION_TYPE} >/dev/null
    boot_end=$(( 1 + 122 ))
    max=$(( $(cat /sys/block/${DSK}/size) * 512 / 1024 / 1024 - 1 ))

    if [ "${PARTITION_LAYOUT}" == "brh" ]; then
        # If the total space available is less than 'root_max' (in Gb) then make
        # the /root partition half the total disk capcity.
        root_max=24
        if [ $max -le $(( ${root_max} * 1024 )) ]; then
            root_end=$(( $max / 2 ))
        else
            root_end=$(( $root_max * 1024 ))
        fi
    else
        root_end=$max
    fi

    echo "==> Creating /boot partition"
    parted -a optimal -s /dev/${DSK} unit MiB mkpart primary 1 $boot_end >/dev/null
    ROOT_PARTITION="${DSK}2"
    echo "==> Creating /root partition"
    parted -a optimal -s /dev/${DSK} unit MiB mkpart primary $boot_end $root_end >/dev/null
    if [ "${PARTITION_LAYOUT}" == "brh" ]; then
        echo "==> Creating /home partition"
        parted -a optimal -s /dev/${DSK} unit MiB mkpart primary $root_end $max >/dev/null
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
    if [ "${PARTITION_LAYOUT}" == "brh" ]; then
        echo "==> Making /home filesystem : ${FS}"
        ${MKFS} ${MKFS_L} home /dev/${DSK}3 >/dev/null
    fi
}

function mount_disks() {
    echo "==> Mounting filesystems"
    mount -t ${FS} ${MOUNT_OPTS} /dev/${ROOT_PARTITION} ${TARGET_PREFIX} >/dev/null
    mkdir -p ${TARGET_PREFIX}/{boot,home}
    mount -t ext2 /dev/${DSK}1 ${TARGET_PREFIX}/boot >/dev/null
    if [ "${PARTITION_LAYOUT}" == "brh" ]; then
        mount -t ${FS} ${MOUNT_OPTS} /dev/${DSK}3 ${TARGET_PREFIX}/home >/dev/null
    fi
}

function build_packages() {
    # Chain packages
    cat packages/base/packages-extra.txt > /tmp/packages.txt
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
            MATE_CHECK=`grep "\[mate\]" /etc/pacman.conf`
            if [ $? -ne 0 ]; then
                echo -e '\n[mate]\nSigLevel = Optional TrustAll\nServer = http://repo.mate-desktop.org/archlinux/$arch' >> /etc/pacman.conf
                if [ "${MODE}" == "update" ]; then
					pacman -Syy
				fi
            fi
        fi

        # Chain the DE packages.
        cat packages/desktop/packages-xorg.txt packages/desktop/packages-${DE}.txt packages/desktop/packages-gst.txt packages/desktop/packages-cups.txt packages/desktop/packages-ttf.txt >> /tmp/packages.txt
    fi
}

function install_packages() {
    # Install packages
    if [ "${MODE}" == "install" ]; then
        pacstrap -c ${TARGET_PREFIX} $(cat packages/base/packages-base.txt /tmp/packages.txt)
        if [ $? -ne 0 ]; then
            echo "ERROR! 'pacstrap' failed. Cleaning up and exitting."
            swapoff -a
            if [ -n "${NFS_CACHE}" ]; then
                umount -fv /var/cache/pacman/pkg
            fi
            if [ "${PARTITION_LAYOUT}" == "brh" ]; then
                umount -fv ${TARGET_PREFIX}/home
            fi
            umount -fv ${TARGET_PREFIX}/{boot,}
            exit 1
        fi
    else
        pacman -Rs --noconfirm heirloom-mailx
        pacman -S --noconfirm --needed $(cat packages/base/packages-base.txt)
        pacman -S --noconfirm --needed $(cat /tmp/packages.txt | grep -Ev "ipw2|syslinux")
    fi
}

function make_fstab() {
    genfstab -t UUID -p ${TARGET_PREFIX} >> ${TARGET_PREFIX}/etc/fstab
}

function enable_multilib() {
    # Only install multilib on workstations, I have no need for it on my Arch "servers".
    if [ "${INSTALL_TYPE}" == "desktop" ] && [ "${CPU}" == "x86_64" ]; then
        sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /etc/pacman.conf
        sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' ${TARGET_PREFIX}/etc/pacman.conf
        echo -en "\nY\nY\nY\nY\nY\n" | pacstrap -c -i ${TARGET_PREFIX} multilib-devel
    fi
}

function build_configuration() {
    # Start building the configuration script
    start_config

    # Configure the hostname.
    add_config "echo ${FQDN} > /etc/hostname"
    add_config "hostnamectl set-hostname --static ${FQDN}"

    # Configure timezone and hwclock
    add_config "echo ${TIMEZONE} > /etc/timezone"
    add_config "ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime"

    # Font and font map
    FONT="ter-116b"

    add_config "echo KEYMAP=${KEYMAP}      > /etc/vconsole.conf"
    add_config "echo FONT=${FONT}         >> /etc/vconsole.conf"
    add_config "echo FONT_MAP=${FONT_MAP} >> /etc/vconsole.conf"
    add_config "sed -i \"s/#${LANG}/${LANG}/\" /etc/locale.gen"
    add_config "echo LANG=${LANG}             >  /etc/locale.conf"
    add_config "echo LC_COLLATE=${LC_COLLATE} >> /etc/locale.conf"
    add_config "locale-gen"
    add_config 'echo "export EDITOR=nano" >> /etc/profile'

    # DO NOT MOVE THIS - It has to be after the early module config ###############
    if [ "${MODE}" == "install" ]; then
        update_early_hooks consolefont
        update_early_hooks keymap
        # Determine the current (not running) Kernel version
        KERNEL_VER=`pacman -Si linux | grep Version | cut -d':' -f2 | sed 's/ //g'`
        add_config "depmod -a ${KERNEL_VER}-ARCH"
        add_config "mkinitcpio -p linux"
        add_config "hwclock --systohc --utc"
    else
        add_config "rm /etc/localtime 2>/dev/null"
    fi
    ###############################################################################

    # Pacman tweaks
    if [ -n "${NFS_CACHE}" ]; then
        # https://wiki.archlinux.org/index.php/Pacman_Tips#Network_shared_pacman_cache
        add_config "sed -i 's/#CleanMethod = KeepInstalled/CleanMethod = KeepCurrent/' /etc/pacman.conf"
    fi
    add_config "sed -i 's/#Color/Color/' /etc/pacman.conf"

    if [ "${INSTALL_TYPE}" == "desktop" ]; then
        if [ "${DE}" == "cinnamon" ]; then
            add_config "systemctl enable lightdm.service"
            add_config "systemctl enable upower.service"
            add_config "systemctl enable accounts-daemon.service"
            add_config "systemctl enable NetworkManager.service"
            add_config "systemctl enable cups.service"
            add_config "systemctl enable bluetooth.service"
        elif [ "${DE}" == "gnome" ]; then
            add_config "systemctl enable gdm.service"
            add_config "systemctl enable upower.service"
            add_config "systemctl enable accounts-daemon.service"
            add_config "systemctl enable NetworkManager.service"
            add_config "systemctl enable cups.service"
            add_config "systemctl enable bluetooth.service"
        elif [ "${DE}" == "kde" ]; then
            add_config "systemctl enable kdm.service"
            add_config "systemctl enable upower.service"
            add_config "systemctl enable NetworkManager.service"
            add_config "systemctl enable cups.service"
            add_config "systemctl enable bluetooth.service"
        elif [ "${DE}" == "lxde" ]; then
            add_config "systemctl enable lxdm.service"
            add_config "systemctl enable upower.service"
            add_config "systemctl enable NetworkManager.service"
            add_config "systemctl enable cups.service"
            add_config "systemctl enable bluetooth.service"
        elif [ "${DE}" == "mate" ]; then
            echo -e '\n[mate]\nSigLevel = Optional TrustAll\nServer = http://repo.mate-desktop.org/archlinux/$arch' >> ${TARGET_PREFIX}/etc/pacman.conf
            add_config "systemctl enable lightdm.service"
            add_config "systemctl enable upower.service"
            add_config "systemctl enable accounts-daemon.service"
            add_config "systemctl enable NetworkManager.service"
            add_config "systemctl enable cups.service"
            add_config "systemctl enable bluetooth.service"
        elif [ "${DE}" == "xfce" ]; then
            add_config "systemctl enable lightdm.service"
            add_config "systemctl enable upower.service"
            add_config "systemctl enable NetworkManager.service"
            add_config "systemctl enable cups.service"
            add_config "systemctl enable bluetooth.service"
        fi
    fi

    if [ -f netctl ]; then
        cp netctl ${TARGET_PREFIX}/etc/netctl/mynetwork
        add_config "netctl enable mynetwork"
    fi

    add_config "sed -i 's/hosts: files dns/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4/' /etc/nsswitch.conf"
    add_config "sed -i '/%wheel ALL=(ALL) ALL/s/^#//' /etc/sudoers"
    add_config "systemctl start sshdgenkeys.service"
    add_config "systemctl enable sshd.service"
    add_config "systemctl enable syslog-ng.service"
    add_config "systemctl enable cronie.service"
    # By default the maximum number of watches is set to 8192, which is rather low.
    # Increasing to ensure Dropbox and MiniDLNA will work correctly.
    add_config 'echo "fs.inotify.max_user_watches = 131072" >> /etc/sysctl.d/98-fs.inotify.max_user_watches.conf'

    if [ "${INSTALL_TYPE}" == "desktop" ]; then
        add_config "systemctl enable avahi-daemon.service"
        add_config "systemctl enable rpc-statd.service"
    fi

    if [ "${BASE_ARCH}" == "x86" ]; then
        add_config "wget http://aur.archlinux.org/packages/pa/packer/packer.tar.gz -O /usr/local/src/packer.tar.gz"
        add_config 'if [ $? -ne 0 ]; then'
        add_config "    echo \"ERROR! Couldn't downloading packer.tar.gz. Skipping packer install.\""
        add_config "else"
        add_config "    cd /usr/local/src"
        add_config "    tar zxvf packer.tar.gz"
        add_config "    cd packer"
        add_config "    makepkg --asroot -s --noconfirm"
        add_config '    pacman -U --noconfirm `ls -1t /usr/local/src/packer/*.pkg.tar.xz | head -1`'
        add_config "    packer -S --noconfirm --noedit tlp"
        add_config "    mkdir -p /etc/systemd/system/graphical.target.wants/"
        add_config "    systemctl enable tlp.service"
        add_config "    systemctl enable tlp-sleep.service"
        add_config "fi"
        # Some SATA chipsets can corrupt data when ALPM is enabled. Disable it
        add_config "sed -i 's/SATA_LINKPWR/#SATA_LINKPWR/' /etc/default/tlp"
    else
        add_config "pacman -S --needed --noconfirm packer"
    fi

    # Install dot files.
    rsync -aq skel/ ${TARGET_PREFIX}/etc/skel/
    rsync -aq skel/ ${TARGET_PREFIX}/root/

    if [ -f users.csv ]; then
        OIFS=${IFS}
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
        done
        IFS=${OIFS}
    fi

    PASSWORD_CRYPT=`openssl passwd -crypt ${PASSWORD}`
    add_config "usermod --password ${PASSWORD_CRYPT} root"

    # Configure the hardware
    add_config "echo 'blacklist pcspkr' > /etc/modprobe.d/blacklist-pcspkr.conf"

    # Add `fstrim` cron job here.
    #  - https://patrick-nagel.net/blog/archives/337
    #  - http://blog.neutrino.es/2013/howto-properly-activate-trim-for-your-ssd-on-linux-fstrim-lvm-and-dmcrypt/
    if [ ${HAS_TRIM} -eq 1 ]; then
        add_config 'echo "#!/usr/bin/env bash"                  >  /etc/cron.daily/trim'
        add_config 'echo "$(date -R)  >> /var/log/trim.log"     >> /etc/cron.daily/trim'
        add_config 'echo "fstrim -v / >> /var/log/trim.log"     >> /etc/cron.daily/trim'
        if [ "${PARTITION_LAYOUT}" == "brh" ]; then
            add_config 'echo "fstrim -v /home >> /var/log/trim.log" >> /etc/cron.daily/trim'
        fi
    fi

    add_config "systemctl enable ntpd"
    add_config "systemctl enable cpupower"

    # Configure PCI/USB device specific stuff
    for BUS in pci usb
    do
        echo "Checking ${BUS} bus"
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
            echo " - Detected ${BUS} bus"
            for DEVICE_CONFIG in hardware/${BUS}/*:*.sh
            do
                echo " - Checkng ${DEVICE_CONFIG}"
                if [ -x ${DEVICE_CONFIG} ]; then
                    DEVICE_ID=`echo ${DEVICE_CONFIG} | cut -f3 -d'/' | cut -d'.' -f1`
                    FOUND_DEVICE=`${DEVICE_FINDER} -d ${DEVICE_ID}`
                    if [ -n "${FOUND_DEVICE}" ]; then
                        # Add the hardware script to the configuration script.
                        echo " - ${DEVICE_ID} detected, adding to config"
                        echo -e "\n#${DEVICE_ID}\n" >>${TARGET_PREFIX}/usr/local/bin/arch-config.sh
                        grep -Ev "#!" ${DEVICE_CONFIG} >> ${TARGET_PREFIX}/usr/local/bin/arch-config.sh
                    else
                        echo " - ${DEVICE_ID} not detected, moving on."
                    fi
                else
                    echo " - ${DEVICE_CONFIG} is not an executable script, skipping."
                fi
            done
        else
            echo " - ${BUS} is not present."
        fi
    done

    if [ "${MODE}" == "install" ]; then
        # Configure any system specific stuff
        for IDENTITY in Product_Name Version Serial_Number UUID SKU_Number
        do
            echo "Checking ${IDENTIFY}"
            FIELD=`echo ${IDENTITY} | sed 's/_/ /g'`
            VALUE=`dmidecode --type system | grep "${FIELD}" | cut -f2 -d':' | sed s'/^ //' | sed s'/ $//' | sed 's/ /_/g'`
            echo " - Checking ${FIELD} for ${VALUE}"
            if [ -x hardware/system/${IDENTITY}/${VALUE}.sh ]; then
                echo " - ${IDENTITY} detected, adding to config."
                # Add the hardware script to the configuration script.
                echo -e "\n#${IDENTITY} - ${VALUE}\n" >>${TARGET_PREFIX}/usr/local/bin/arch-config.sh
                grep -Ev "#!" hardware/system/${IDENTITY}/${VALUE}.sh >> ${TARGET_PREFIX}/usr/local/bin/arch-config.sh
            else
                echo " - ${IDENTITY}/${VALUE}.sh not detected, moving on."
            fi
        done
    fi
}

function apply_configuration() {
    if [ "${MODE}" == "install" ]; then
        add_config "syslinux-install_update -iam"
        arch-chroot ${TARGET_PREFIX} /usr/local/bin/arch-config.sh
        cp {splash.png,terminus.psf,syslinux.cfg} ${TARGET_PREFIX}/boot/syslinux/
    else
        /usr/local/bin/arch-config.sh
    fi
}

function cleanup() {
    swapoff -a && sync
    if [ -n "${NFS_CACHE}" ]; then
        addlinetofile "${NFS_CACHE} /var/cache/pacman/pkg nfs defaults,relatime,noauto,x-systemd.automount,x-systemd.device-timeout=5s 0 0" ${TARGET_PREFIX}/etc/fstab
        if [ "${MODE}" == "install" ]; then
            umount -fv /var/cache/pacman/pkg
        fi
    fi

    if [ "${MODE}" == "install" ]; then
        if [ "${PARTITION_LAYOUT}" == "brh" ]; then
            umount -fv ${TARGET_PREFIX}/home
        fi
        umount -fv ${TARGET_PREFIX}/{boot,}
    fi

    echo "All done!"
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

if [ $(id -u) -ne 0 ]; then
	echo "ERROR! $(basename ${0}) must be run as root."
	exit 1
fi

if [ "${CPU}" != "armv6l" ] && [ "${CPU}" != "armv7l" ] && [ "${CPU}" != "i686" ] && [ "${CPU}" != "x86_64" ]; then
    echo "ERROR! `basename ${0}` is designed for armv6l, armv7l, i686, x86_64 platforms only."
    echo " - Contributions welcome - https://github.com/flexiondotorg/ArchInstaller/"
    exit 1
fi

if [ -z "${PASSWORD}" ] && [ "${MODE}" == "install" ]; then
    echo "ERROR! The 'root' password has not been provided."
    echo " - See `basename ${0}` -h"
    exit 1
fi

if [ ! -f /usr/share/zoneinfo/${TIMEZONE} ]; then
    echo "ERROR! I can't find the zone info for '${TIMEZONE}'."
    echo " - See `basename ${0}` -h"
    exit 1
fi

if [ "${INSTALL_TYPE}" != "desktop" ] && [ "${INSTALL_TYPE}" != "server" ]; then
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

# Install the requirements
if [ "${MODE}" == "install" ]; then
    pacman -Syy --noconfirm --needed dmidecode
else
	pacman -Syu --needed --noconfirm
fi

query_disk_subsystem
test_nfs_cache
summary

if [ "${MODE}" == "install" ]; then
    format_disks
    mount_disks
fi

build_packages
install_packages

if [ "${MODE}" == "install" ]; then
    make_fstab
fi

enable_multilib
build_configuration
apply_configuration
cleanup
