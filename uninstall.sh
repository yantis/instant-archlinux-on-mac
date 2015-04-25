#!/bin/bash

#==============================================================================
#==============================================================================
#         Copyright (c) 2015 Jonathan Yantis
#               yantis@yantis.net
#          Released under the MIT license
#==============================================================================
#==============================================================================

# Usage:
# curl -sL goo.gl/yWkbhe | sh

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

  # VirtualBox uninstall says to click the icon =(.
  # https://www.virtualbox.org/manual/ch02.html#idp50285088
  read -p "Double Click the Uninstall Icon in the VirtualBox Volume then hit [ENTER]"

  hdiutil unmount /Volumes/VirtualBox/

  # Unrem this to remove the downloaded install file.
  # rm VirtualBox-4.3.26-98988-OSX.dmg
fi

# vim:set ts=2 sw=2 et:
