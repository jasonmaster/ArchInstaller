#!/usr/bin/env bash

# Merge new *.pac{new,orig,save} configuration files with their originals

if [ `id -u` -ne 0 ]; then
    echo "ERROR! This script must be executed as root."
    exit 1
fi

if [ -z "${DISPLAY}" ] && [ `pidof X` -ne 0 ] ; then
    echo "ERROR! This script requires an X11 session to work."
    exit 1
fi

TEST_DIFFUSE=`which diffuse`
if [ $? -ne 0 ]; then
    pacman -Syy --needed --noconfirm diffuse
fi

echo "Looking for .pac{new,orig,save} files"
pacnew=`egrep "pac(new|orig|save)" /var/log/pacman.log | cut -d':' -f3 | cut -d' ' -f5 | sort -u`

# Check if any .pacnew configurations are found
if [[ -z "$pacnew" ]]; then
    echo "No configurations require updating."
    exit
fi

for config in $pacnew
do
    original=`echo ${config} | sed -e 's/\.pacnew//' -e 's/\.pacsave//' -e 's/\.pacorig//'`
    if [ -f ${config} ] && [ -f ${original} ]; then
        echo " - ${original} requires merging with ${config}"
        
        # Diff original and new configuration to merge
        diffuse ${original} ${config} 2>/dev/null &
        wait
        
        # Remove .pac{new,save,orig} file?
        echo
        read -p "Are you ready to delete '${config}'? [Y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo " - rm -f ${config}"
            rm -f "${config}"
        fi
    else
        echo " - ${original} already merged."
    fi
done
