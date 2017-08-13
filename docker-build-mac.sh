#!/bin/bash

#==============================================================================
#==============================================================================
#         Copyright (c) 2015 Jonathan Yantis
#               yantis@yantis.net
#          Released under the MIT license
#==============================================================================
#==============================================================================

###############################################################################
# Exit on any error whatsoever
# You should be able to just rerun the script at any point and it should
# recover where it left off from.
###############################################################################
set -e
set -u

###############################################################################
# Install homebrew 
###############################################################################
if ! hash brew 2> /dev/null; then
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" </dev/null
else
  echo "Updating homebrew"
  if !  brew update; then
    echo "Homerbrew Update Error. Fixing Permissions"
    sudo chown -R $(whoami) /usr/local
    echo "Attempting to fix and update homebrew"
    brew uninstall --force brew-cask
    brew update
  fi
fi

###############################################################################
# Install Virtualbox 
###############################################################################
if ! hash vboxmanage 2> /dev/null; then
  echo "*** Installing VirtualBox ***"

  # curl -OL http://download.virtualbox.org/virtualbox/5.1.8/VirtualBox-5.1.8-111374-OSX.dmg
  curl -OL http://download.virtualbox.org/virtualbox/5.1.14/VirtualBox-5.1.14-112924-OSX.dmg

  # hdiutil mount VirtualBox-5.1.8-111374-OSX.dmg
  hdiutil mount VirtualBox-5.1.14-112924-OSX.dmg

  sudo installer -pkg /Volumes/VirtualBox/VirtualBox.pkg -target /
  sleep 2
  hdiutil unmount /Volumes/VirtualBox/
  # rm VirtualBox-5.0.24-108355-OSX.dmg
fi

###############################################################################
# Install docker-machine
###############################################################################
if ! hash docker-machine 2> /dev/null; then
  echo "*** Installing Docker Machine***"
  if ! brew install docker-machine; then
    echo "Xcode 8.1 error most likely. Sadly for now you need to get this from developer.apple.com and install by hand "
    exit 1
    # echo "Xcode 8.1 error most likely so installing from the source site"
    # curl -L https://github.com/docker/machine/releases/download/v0.8.2/docker-machine-`uname -s`-`uname -m` >/usr/local/bin/docker-machine
    # chmod +x /usr/local/bin/docker-machine
  fi
fi

###############################################################################
echo "Initialize docker-machine"
###############################################################################
if ! docker-machine status docker-vm 2> /dev/null; then
  echo "*** Initialize docker-machine ***"
  docker-machine create --driver virtualbox docker-vm
fi

###############################################################################
# Install Docker 
###############################################################################
if ! hash docker 2> /dev/null; then
  echo "Installing docker"
  if ! brew install docker; then
    echo "Xcode 8.1 error most likely. Sadly for now you need to get this from developer.apple.com and install by hand "
    exit 1
  fi
fi


###############################################################################
# Install boot2docker
###############################################################################
if ! hash boot2docker 2> /dev/null; then
  echo "Installing boot2docker"
  if ! brew install boot2docker; then
    echo "Xcode 8.1 error most likely. Sadly for now you need to get this from developer.apple.com and install by hand "
    exit 1
  fi
fi

###############################################################################
echo "Get Boot2Docker exports"
docker-machine regenerate-certs docker-vm --force
eval "$(docker-machine env docker-vm)"
###############################################################################

###############################################################################
# Download the rootfs
###############################################################################
if [ ! -f ~/airootfs.sfs ];
then
  echo "Downloading rootfs image"
  cd ~
  # curl -OL http://mirror.rackspace.com/archlinux/iso/2016.10.01/arch/x86_64/airootfs.sfs
  curl -OL http://mirror.rackspace.com/archlinux/iso/2017.08.01/arch/x86_64/airootfs.sfs
fi

###############################################################################
# Build the docker container 
###############################################################################
docker build -t yantis/instant-archlinux-on-mac .

###############################################################################
# Restore security 
###############################################################################
sudo chmod 660 /dev/${ROOTDISK}s1
sudo sed -i.bak "s/Defaults timestamp_timeout=-1/#Defaults timestamp_timeout=-1/" /etc/sudoers

###############################################################################
# All Done 
###############################################################################

# vim:set ts=2 sw=2 et:
