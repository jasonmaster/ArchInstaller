#!/usr/bin/env bash

pacman -S --needed --noconfirm sound-juicer
# TODO
#  - Do this for all users
# Use the 'standard' preset by default. This preset should generally be
# transparent to most people on most music and is already quite high in quality.
# The resulting bitrate should be in the 170-210kbps range, according to music
# complexity.
sudo -u ${SUDO_USER} gconftool-2 --type string --set /system/gstreamer/0.10/audio/profiles/mp3/pipeline "audio/x-raw-int,rate=44100,channels=2 ! lame name=enc preset=1001 ! id3v2mux"

