#!/usr/bin/env bash

if [ `id -u` != 0 ]; then
    echo "ERROR! You must be root to execute this script."
    exit 1
fi

if [ -z "${1}" ] || [ ! -f ${1} ]; then
    echo "ERROR! You must provide an installation profile."
    echo "       Creating an app list."
    ls -1 --color=never packages/app/* | grep -v _pac
    exit 1
fi

OIFS=${IFS}
IFS=$'\n';
for APP in `cat ${1}`
do
    if [ -f "${APP}" ]; then
        echo "Installing ${APP}"
        ${APP}
    else
        echo "${APP} is not an install profile, skipping."
    fi
done
IFS=${OIFS}
