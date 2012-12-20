#!/usr/bin/env bash

log="${PWD}/`basename ${0}`.log"
rm $log 2>/dev/null

if [ -f common.sh ]; then
    source common.sh
else
    echo "ERROR! Could not source 'common.sh'"
    exit 1
fi

exit 0
