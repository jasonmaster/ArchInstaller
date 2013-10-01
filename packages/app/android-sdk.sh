#!/usr/bin/env bash

./jdk6.sh
packer -S --noedit --noconfirm android-sdk-platform-tools android-apktool
