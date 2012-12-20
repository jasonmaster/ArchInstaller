#!/usr/bin/env bash

if [ -f common.sh ]; then
    source common.sh
else
    echo "ERROR! Could not source 'common.sh'"
    exit 1
fi

exit 0
