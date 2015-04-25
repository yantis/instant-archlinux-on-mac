#!/bin/bash

#==============================================================================
#==============================================================================
#         Copyright (c) 2015 Jonathan Yantis
#               yantis@yantis.net
#          Released under the MIT license
#==============================================================================
#==============================================================================

###############################################################################
# Uninstall Boot2Docker
###############################################################################
boot2docker stop
boot2docker delete
rm -r ~/VirtualBox\ VMs

###############################################################################
# Uninstall virtualbox 
###############################################################################
if hash vboxmanage 2> /dev/null; then

  if [ ! -f ~/VirtualBox-4.3.26-98988-OSX.dmg ];
  then
    curl -OL http://download.virtualbox.org/virtualbox/4.3.26/VirtualBox-4.3.26-98988-OSX.dmg
  fi

  hdiutil mount VirtualBox-4.3.26-98988-OSX.dmg
  sudo installer -pkg /Volumes/VirtualBox/VirtualBox.pkg -target /Volumes/Macintosh\ HD
  sleep 2
  hdiutil unmount /Volumes/VirtualBox/

  # Unrem this to remove the downloaded install file.
  # rm VirtualBox-4.3.26-98988-OSX.dmg
fi

# vim:set ts=2 sw=2 et:
