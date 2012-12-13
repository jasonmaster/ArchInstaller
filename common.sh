error_msg() {
    local MSG="${1}"
    echo "${MSG}"
    exit 1
}

cecho() {
    echo -e "$1"
    echo -e "$1" >>"$log"
    tput sgr0;
}

ncecho() {
    echo -ne "$1"
    echo -ne "$1" >>"$log"
    tput sgr0
}

spinny() {
    echo -ne "\b${sp:i++%${#sp}:1}"
}

progress() {
    ncecho "  ";
    while [ /bin/true ]; do
        kill -0 $pid 2>/dev/null;
        if [[ $? = "0" ]]; then
            spinny
            sleep 0.25
        else
            ncecho "\b\b";
            wait $pid
            retcode=$?
            echo "$pid's retcode: $retcode" >> "$log"
            if [[ $retcode = "0" ]] || [[ $retcode = "255" ]]; then
                cecho success
            else
                cecho failed
                echo -e " [i] Showing the last 10 lines from $log";
                tail -n10 "$log"
                exit 1;
            fi
            break 1; #was2
        fi
    done
}

check_root() {
    if [ "$(id -u)" != "0" ]; then
        error_msg "ERROR! You must execute the script as the 'root' user."
    fi
}

check_user() {
    if [ "$(id -u)" == "0" ]; then
        error_msg "ERROR! You must execute the script as a normal user."
    fi
}

check_sudo() {
    if [ ! -e /usr/bin/sudo ]; then
        error_msg "ERROR! You must install 'sudo'."
    fi

    if [ ! -n ${SUDO_USER} ]; then
        error_msg "ERROR! You must invoke the script using 'sudo'."
    fi
}

check_archlinux() {
    if [ ! -e /etc/arch-release ]; then
        error_msg "ERROR! You must execute the script on Arch Linux."
    fi
}

check_hostname() {
    if [ `echo ${HOSTNAME} | sed 's/ //g'` == "" ]; then
        error_msg "ERROR! Hostname is not configured."
    fi
}

check_domainname() {
    DOMAINNAME=`echo ${HOSTNAME} | cut -d'.' -f2- | sed 's/ //g'`

    # Hmm, still no domain name. Keep looking...
    if [ "${DOMAINNAME}" == "" ]; then
        DOMAINNAME=`grep domain /etc/resolv.conf | sed 's/domain //g' | sed 's/ //g'`
    fi

    # OK, give up.
    if [ "${DOMAINNAME}" == "" ]; then
        error_msg "ERROR! Domain name is not configured."
    fi
}

check_ip() {
    IP_ADDR=`ip addr 2>/dev/null | egrep -o '([0-9]{1,3}\.){3}[0-9]{1,3}' | egrep -v '255|(127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})' | sed 's/ //g'`
    if [ $? -ne 0 ]; then
        error_msg "ERROR! Could not find valid IP address."
    fi
}

check_cpu() {
    grep -q "^flags.*\blm\b" /proc/cpuinfo && CPU="x86_64" || CPU="i686"
}

check_vga() {
    # Determine video chipset.
    # TODO 
    #  - Detect proprietary nVidia and ATI/AMD.
    #  - Unichrome (or whatever) support.
    #  - Query sysfs with `systool -m i915 -av`
    ncecho " [x] Detecting video chipset "
    if [ -f /sys/kernel/debug/dri/0/name ]; then
        VIDEO_KMS=`cat /sys/kernel/debug/dri/0/name | cut -f1 -d' '`
        case ${VIDEO_KMS} in
            "i915" )
                cecho Intel
                VIDEO_DRI="intel-dri"
                VIDEO_DDX="xf86-video-intel"
                VIDEO_DECODER="libva-intel-driver"
                VIDEO_MODPROBE="options i915 modeset=1 i915_enable_rc6=1 i915_enable_fbc=1 i915.lvds_downclock=1 i915.semaphores=1"
                #TODO - Check for fbc support.
                ;;
            "radeon" )
                cecho AMD/ATI
                VIDEO_DRI="ati-dri"
                VIDEO_DDX="xf86-video-ati"
                VIDEO_DECODER="libva-vdpau-driver"
                VIDEO_MODPROBE="options radeon modeset=1"
                # TODO - Add `radeon.pcie_gen2=1` is the card is PCIe.
                # http://wiki.x.org/wiki/RadeonFeature#Linux_kernel_parameters
                ;;
            "nouveau" )
                cecho Nvidia
                VIDEO_DRI="nouveau-dri"
                VIDEO_DDX="xf86-video-nouveau"
                VIDEO_DECODER="libva-vdpau-driver"
                VIDEO_MODPROBE="options nouveau modeset=1"
                ;;
        esac
    else
        local VGA=`lspci | grep VGA`
        echo ${VGA} | tr "[:upper:]" "[:lower:]" | grep -q "virtualbox"
        if [ $? -eq 0 ]; then
            cecho VirtualBox
            VIDEO_DRI=""
            VIDEO_DDX="virtualbox-guest-modules"
            VIDEO_KMS="vboxvideo"
            VIDEO_DECODER=""
            VIDEO_MODPROBE=""
        else
            cecho VESA
            VIDEO_DRI=""
            VIDEO_DDX="xf86-video-vesa"
            VIDEO_KMS=""
            VIDEO_DECODER=""
            VIDEO_MODPROBE=""
        fi
    fi
}

check_wireless() {
    lspci | grep -q BCM4312
    if [ $? -eq 0 ]; then
        WIRELESS_PKG="dkms-broadcom-wl"
        WIRELESS_MOD="wl"
    else
        WIRELESS_PKG=""
        WIRELESS_MOD=""
    fi
}

replaceinfile() {
    SEARCH=${1}
    REPLACE=${2}
    FILEPATH=${3}
    FILEBASE=`basename ${3}`

    sed -e "s/${SEARCH}/${REPLACE}/" ${FILEPATH} > /tmp/${FILEBASE} 2>"$log"
    if [ ${?} -eq 0 ]; then
        mv /tmp/${FILEBASE} ${FILEPATH}
    else
        cecho "failed: ${SEARCH} - ${FILEPATH}"
    fi
}

addlinetofile() {
    ADD_LINE=${1}
    FILEPATH=${2}

    CHECK_LINE=`grep -F "${ADD_LINE}" ${FILEPATH}`
    if [ ${?} -ne 0 ]; then
        echo "${ADD_LINE}" >> ${FILEPATH}
    fi
}

add_user_to_group() {
    local _USER=${1}
    local _GROUP=${2}

    if [ -z "${_GROUP}" ]; then
        error_msg "ERROR! 'add_user_to_group' was not given enough parameters."
    fi

    ncecho " [x] Adding ${_USER} to ${_GROUP} "
    gpasswd -a ${_USER} ${_GROUP} >>"$log" 2>&1 &
    pid=$!;progress $pid
}

system_application_menu() {
    ncecho " [x] Adding menu entry for ${1} "
    echo "[Desktop Entry]"  >  /usr/share/applications/${1}.desktop
    echo "Version=1.0"      >> /usr/share/applications/${1}.desktop
    echo "Exec=${2}"        >> /usr/share/applications/${1}.desktop
    echo "Icon=${3}"        >> /usr/share/applications/${1}.desktop
    echo "Name=${4}"        >> /usr/share/applications/${1}.desktop
    echo "Comment=${4}"     >> /usr/share/applications/${1}.desktop
    echo "Encoding=UTF-8"   >> /usr/share/applications/${1}.desktop
    echo "Terminal=false"   >> /usr/share/applications/${1}.desktop
    echo "Type=Application" >> /usr/share/applications/${1}.desktop
    echo "Categories=${5}"  >> /usr/share/applications/${1}.desktop
    cecho success
}

pacman_sync() {
    local MODIFY=`stat /var/lib/pacman/sync | egrep ^Modify | cut -d':' -f2 | cut -d' ' -f2`
    local TODAY=`date +%Y-%m-%d`
    if [ "${MODIFY}" != "${TODAY}" ]; then
        ncecho " [x] Syncing (arch) "
        pacman -Syy >>"$log" 2>&1 &
        pid=$!;progress $pid
    fi
}

pacman_install() {
    for PKG in ${1}
    do
        PKG_INSTALLED=`pacman -Q ${PKG} 2>/dev/null`
        if [ $? -eq 1 ]; then
            ncecho " [x] Installing (pacman) ${PKG} "
            pacman -S --noconfirm --needed ${PKG} >>"$log" 2>&1 &
            pid=$!;progress $pid
        else
            cecho " [x] Installing (pacman) ${PKG} exists "
        fi
    done
}

pacman_remove() {
    for PKG in ${1}
    do
        PKG_INSTALLED=`pacman -Q ${PKG} 2>/dev/null`
        if [ $? -eq 0 ]; then
            ncecho " [x] Removing (pacman) ${PKG} "
            pacman -R --noconfirm ${PKG} >>"$log" 2>&1 &
            pid=$!;progress $pid
        fi
    done
}

# $1 - group to install
# $2 - packages to exlcude from group
pacman_install_group() {
    # Loop through any excluded packages and remove them
    if [ -n "${2}" ]; then
        local GROUP_PKGS=`pacman -Sqg ${1}`
        for EXCLUDE in ${2}
        do
            local GROUP_PKGS=`echo "${GROUP_PKGS}" | grep -x -v ${EXCLUDE}`
        done

        # pacman requires all packages in one line.
        local GROUP_PKGS=`echo "${GROUP_PKGS}" | tr '\n' ' '`
        pacman_install "${GROUP_PKGS}"
    else
        local GROUP_PKG=${1}
        pacman_install "${GROUP_PKG}"
    fi
}

packer_clean() {
    # Cleanup as packer leftovers
    for DIR in /tmp /var/tmp ${TMPDIR}
    do
        rm -rf ${DIR}/packertmp-*
        rm -rf ${DIR}/packerbuild-*
    done
}

packer_install() {
    export TMPDIR=/var/tmp
    local _OPTS="${2}"
    for PKG in ${1}
    do
        PKG_INSTALLED=`pacman -Q ${PKG} 2>/dev/null`
        if [ $? -eq 1 ]; then
            #sudo -u ${SUDO_USER} packer -S ${_OPTS} --noconfirm --noedit ${PKG}
            ncecho " [x] Installing (packer) ${PKG} "
            packer -S ${_OPTS} --noconfirm --noedit ${PKG} >>"$log" 2>&1 &
            pid=$!;progress $pid
        else
            cecho " [x] Installing (packer) ${PKG} success "
        fi
    done
}

pacman_upgrade() {
    ncecho " [x] Upgrading packages (pacman) "
    pacman -Syu --noconfirm >>"$log" 2>&1 &
    pid=$!;progress $pid
}

packer_upgrade() {
    export TMPDIR=/var/tmp
    ncecho " [x] Upgrading packages (packer) "
    packer -Syu --auronly --noconfirm --noedit >>"$log" 2>&1 &
    pid=$!;progress $pid
}

packer_upgrade_devel() {
    export TMPDIR=/var/tmp
    ncecho " [x] Upgrading dev packages (packer) "
    packer -Syu --auronly --noconfirm --noedit --devel >>"$log" 2>&1 &
    pid=$!;progress $pid
}

makepkg_install() {
    local _PKG="${1}"
    wget_tarball ${_PKG}

    cd /tmp/${TARBALL_DIR}
    sudo -u ${SUDO_USER} makepkg -s --noconfirm

    NEW_PKG=`ls -1t ${TARBALL_DIR}*.pkg.tar.xz | head -1`

    ncecho " [x] Installing (makepkg) ${NEW_PKG} "
    pacman -U --noconfirm ${NEW_PKG} >>"$log" 2>&1 &
    pid=$!;progress $pid
}

cpan_install() {
    ncecho " [x] Installing (cpan) ${1} "
    cpan ${1} >>"$log" 2>&1 &
    pid=$!;progress $pid
}

pip_install() {
    ncecho " [x] Installing (pip)  ${1} "
    pip install ${1} >>"$log" 2>&1 &
    pid=$!;progress $pid
}

rc_d() {
    ncecho " [x] rc.d ${1} ${2} "
    rc.d ${1} ${2} >>"$log" 2>&1 &
    pid=$!;progress $pid
}

wget_tarball() {
    local TARBALL_URL="${1}"
    if [ "${2}" == "" ]; then
        local TARBALL=`echo ${TARBALL_URL##*\/}`
    else
        local TARBALL="${2}"
    fi
    local TARBALL_FORMAT=`echo ${TARBALL##*\.}`
    TARBALL_DIR=`echo ${TARBALL} | sed 's/\.tgz//g' | sed 's/\.tar//g' | sed 's/\.gz//g' | sed 's/\.bz2//g' | sed 's/\.xz//g'`

    cd /tmp
    rm -rf /tmp/${TARBALL_DIR}
    ncecho " [x] Downloading ${TARBALL_URL} "
    wget -c "${TARBALL_URL}" -O /tmp/${TARBALL} >>"$log" 2>&1 &
    pid=$!;progress $pid

    if [ "${TARBALL_FORMAT}" == "bz2" ]; then
        ncecho " [x] Unpacking ${TARBALL} "
        sudo -u ${SUDO_USER} tar jxvf ${TARBALL} >>"$log" 2>&1 &
        pid=$!;progress $pid
    elif [ "${TARBALL_FORMAT}" == "gz" ] || [ "${TARBALL_FORMAT}" == "tgz" ]; then
        ncecho " [x] Unpacking ${TARBALL} "
        sudo -u ${SUDO_USER} tar zxvf ${TARBALL} >>"$log" 2>&1 &
        pid=$!;progress $pid
    elif [ "${TARBALL_FORMAT}" == "xz" ]; then
        ncecho " [x] Unpacking ${TARBALL} "
        sudo -u ${SUDO_USER} tar Jxvf ${TARBALL} >>"$log" 2>&1 &
        pid=$!;progress $pid
    else
        error_msg "ERROR! Unknown tarball format : ${TARBALL}"
    fi
}

wget_install_generic() {
    local URL="${1}"
    local INST_DIR="${2}"
    local FILE=`echo ${URL##*\/}`

    mkdir -p ${INST_DIR}
    ncecho " [x] Downloading ${FILE} "
    wget -c "${URL}" -O ${INST_DIR}/${FILE} >>"$log" 2>&1 &
    pid=$!;progress $pid
}

rebuild_init() {
    ncecho " [x] Rebuilding init "
    mkinitcpio -p linux >>"$log" 2>&1 &
    pid=$!;progress $pid
}

update_early_modules() {
    local NEW_MODULE=${1}
    local OLD_ARRAY=`egrep ^MODULES= /etc/mkinitcpio.conf`

    if [ -n "${NEW_MODULE}" ]; then
        # Determine if the new module is already listed.
        _EXISTS=`echo ${OLD_ARRAY} | grep ${NEW_MODULE}`
        if [ $? -eq 1 ]; then

            source /etc/mkinitcpio.conf
            if [ -z "${MODULES}" ]; then
                NEW_MODULES="${NEW_MODULE}"
            else
                NEW_MODULES="${MODULES} ${NEW_MODULE}"
            fi
            replaceinfile "MODULES=\"${MODULES}\"" "MODULES=\"${NEW_MODULES}\"" /etc/mkinitcpio.conf
            rebuild_init            
        fi
    fi
}

update_early_hooks() {
    local NEW_HOOK=${1}
    local OLD_ARRAY=`egrep ^HOOKS= /etc/mkinitcpio.conf`

    if [ -n "${NEW_HOOK}" ]; then
        # Determine if the new module is already listed.
        _EXISTS=`echo ${OLD_ARRAY} | grep ${NEW_HOOK}`
        if [ $? -eq 1 ]; then

            source /etc/mkinitcpio.conf
            if [ -z "${HOOKS}" ]; then
                NEW_HOOKS="${NEW_HOOK}"
            else
                NEW_HOOKS="${HOOKS} ${NEW_HOOK}"
            fi
            replaceinfile "HOOKS=\"${HOOKS}\"" "MODULES=\"${NEW_HOOKS}\"" /etc/mkinitcpio.conf
            rebuild_init
        fi
    fi
}

system_ctl () {
    local ACTION=${1}
    local OBJECT=${2}
    ncecho " [x] systemdctl ${ACTION} ${OBJECT} "
    systemdctl ${ACTION} ${OBJECT} >>"$log" 2>&1
    #pid=$!;progress $pid
    cecho success
}
