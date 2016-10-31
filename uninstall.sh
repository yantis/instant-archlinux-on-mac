#!/bin/bash

#==============================================================================
#==============================================================================
#         Copyright (c) 2016 Jonathan Yantis
#               yantis@yantis.net
#          Released under the MIT license
#==============================================================================
#==============================================================================


###############################################################################
# Set the disk we are working on. For USB this may change later.
# The default is disk0
###############################################################################
ROOTDISK=disk0

set -u

###############################################################################
# Keep trying to unmount for up to 10 seconds. Some slow USBs can take a bit.
###############################################################################
unmount()
{
  timeout=$(($(date +%s) + 10))
  until sudo diskutil umount "${1}" 2>/dev/null || [[ $(date +%s) -gt $timeout ]]; do
   :
  done
}

###############################################################################
# Disable sudo password request time out for now.
# Editing sudoers this way on a mac really is no big deal.
# You can quickly fix any mistakes you make to it by:
# Hitting shift+⌘-+g typing /etc. Selecting sudoers and hitting ⌘-+i
# then unlock it and change your permissions to fix it.
###############################################################################
echo "Temporarily Disabling sudo password timeout"
sudo sh -c 'echo "\nDefaults timestamp_timeout=-1">>/etc/sudoers'

##############################################################################
# Uninstall Boot2Docker
###############################################################################
if hash boot2docker 2> /dev/null; then
  echo "Removing boot2docker"
  boot2docker stop
  boot2docker delete
  brew uninstall --force boot2docker
fi

###############################################################################
# Uninstall docker"
###############################################################################
if hash docker-machine 2> /dev/null; then
  # echo "Remove our docker image"
  # docker rmi yantis/instant-archlinux-on-mac

  echo "Uninstalling docker-vm"
  yes | docker-machine rm docker-vm

  ###############################################################################
  # Uninstall docker
  ###############################################################################
  echo "Uninstalling docker"
  brew uninstall --force docker-machine
fi

###############################################################################
# Uninstall virtualbox
###############################################################################
if hash vboxmanage 2> /dev/null; then

  if [ ! -f VirtualBox-5.1.8-111374-OSX.dmg ];
  then
    curl -OL http://download.virtualbox.org/virtualbox/5.1.8/VirtualBox-5.1.8-111374-OSX.dmg
  fi

  hdiutil mount VirtualBox-5.1.8-111374-OSX.dmg
  sudo sh /Volumes/VirtualBox/VirtualBox_Uninstall.tool --unattended
  sleep 2
  hdiutil unmount /Volumes/VirtualBox/

  # Unrem this to remove the downloaded install file.
  # rm VirtualBox-4.3.26-98988-OSX.dmg
fi

###############################################################################
# Remove Archlinux Volume
###############################################################################
if [ -d  /Volumes/1 ]; then
  echo "Removing ArchLinux Volume"

  # echo "Get our ext4 volume. It should always be at disk0s4. But just in case."
  EXT4VOL=$(diskutil list ${ROOTDISK} | grep "Linux Filesystem" | awk '{print $7}')

  echo $EXT4VOL

  # Sanity Check
  if echo $EXT4VOL | grep -q "${ROOTDISK}s"  ; then
    echo "Our ext4 volume is $EXT4VOL"
  fi

  unmount $EXT4VOL
  sudo rm -rf /Volumes/1

  # Todo need to delete the Volume with diskutil

fi

###############################################################################
# Remove rEFInd
###############################################################################

if [ ! -d  /Volumes/ESP ]; then
  echo "Mounting EFI volume"
  sudo mkdir -p /Volumes/ESP
  sudo mount -t msdos /dev/disk0s1 /Volumes/ESP
  echo "rEFInd installed uninstalling it."
  sudo rm -rf /Volumes/ESP/EFI/refind
fi

###############################################################################
# Restore security 
###############################################################################
sudo sed -i.bak "s/Defaults timestamp_timeout=-1/#Defaults timestamp_timeout=-1/" /etc/sudoers

###############################################################################
# All Done 
###############################################################################

# vim:set ts=2 sw=2 et:
