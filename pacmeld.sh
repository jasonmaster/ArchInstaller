#!/usr/bin/env bash
# Merge new *.pacnew configuration files with their originals

if [ -z "${DISPLAY}" ]; then
    echo "ERROR! This script requires an X11 session to work."
    exit 1
fi

echo "Looking for .pacnew files"
pacnew=`egrep "pac(new|orig|save)" /var/log/pacman.log | cut -d':' -f3 | cut -d' ' -f5`

# Check if any .pacnew configurations are found
if [[ -z "$pacnew" ]]; then
    echo "No configurations to update"
    exit
fi

for config in $pacnew
do
    original=`echo ${config} | sed -e 's/\.pacnew//' -e 's/\.pacsave//' -e 's/\.pacorig//'`
    #echo $config
    #echo $original
    if [ -f ${config} ] && [ -f ${original} ]; then
        echo "${original} requires merging with ${config}"
        # Diff original and new configuration to merge
        gksudo meld ${original} ${config} 2>/dev/null &
        wait
        # Remove .pacnew file?
        while true; do
            read -p " Delete \""$config"\"? (Y/n): " Yn
            case $Yn in
                [Yy]* ) sudo rm "$config" && \
                        echo " Deleted \""$config"\"."
                        break
                        ;;
                [Nn]* ) break;;
                *     ) echo " Answer (Y)es or (n)o." ;;
            esac
        done
    else
        echo " - ${original} has been merged."
    fi
done
