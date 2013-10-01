#!/usr/bin/env bash

packer -S --noedit --noconfirm dropbox
echo "fs.inotify.max_user_watches = 131072" > /etc/sysctl.d/98-dropbox.conf


