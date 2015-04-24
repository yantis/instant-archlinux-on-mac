#!/bin/bash

#==============================================================================
#==============================================================================
#         Copyright (c) 2015 Jonathan Yantis
#               yantis@yantis.net
#          Released under the MIT license
#==============================================================================
#==============================================================================

###############################################################################
# USAGE:
# sh mac-install.sh 50 (would leave 50GB for mac and the rest for Arch Linux) 
# sh mac-install.sh USB (Installs to USB drive - Still needs more work on boot)

###############################################################################
# Set the disk we are working on. For USB this may change later.
# The default is disk0
###############################################################################
ROOTDISK=disk0

###############################################################################
# Exit on any error whatsoever
# You should be able to just rerun the script at any point and it should
# recover where it left off from.
###############################################################################
set -e
set -u

###############################################################################
# Usage
###############################################################################
# Exit the script if the user didn't specify MacOS volume size 
if [ "$#" -ne 1 ]; then
  echo "You must either specify USB or the new MacOs Volume size"
  echo ""
  echo "In specifiing the size you want your MacOs Volume to be"
  echo "It must be at least as big as the data it contains"
  echo "On a new install 30GB probably works OK if you are going for minimal"
  echo "In this case you would run the script with 30 as the argument"
  exit 1
fi

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

###############################################################################
# Mute startup chime
# Unrem this to mute the startup chime (or set the volume 01 to 99 I think)
###############################################################################
# sudo /usr/sbin/nvram SystemAudioVolume=%01

###############################################################################
# Update Mac OSX 
# particually any firmware updates (though lets leave this up to the user)
###############################################################################
# sudo softwareupdate -i -a

###############################################################################
# Convert from Core Storage to HFS+ if needed. 
###############################################################################
if diskutil info ${ROOTDISK}s2 | grep -q "Core Storage"  ; then
  #TODO check if encrypted first.and decrypt
  #https://derflounder.wordpress.com/2011/11/23/using-the-command-line-to-unlock-or-decrypt-your-filevault-2-encrypted-boot-drive/

  #TODO Play with the fusion drive (the latest imac retina has one)
  # Note if they have a fusion drive then this will most likely fail with an error. 
  # "This operation can only be performed if there is one Core Storage physical voluume present in the group"

  echo "Disk ${ROOTDISK}s2 is a Core Storage Volume. Converting to HFS+"
  COREVOLUME=$(diskutil list | grep -A1 "Logical Volume on ${ROOTDISK}s2" | tail -1)
  sudo diskutil coreStorage revert $COREVOLUME
  echo "YOU MUST REBOOT and rerun the script to continue from this point."
  exit 1
fi

###############################################################################
# Install CLI developer tools (a dependency for homebrew and more)
###############################################################################
echo "Installing CLI developer tools"
if ! hash brew 2> /dev/null; then
  curl -O https://raw.githubusercontent.com/timsutton/osx-vm-templates/master/scripts/xcode-cli-tools.sh
  sudo sh xcode-cli-tools.sh
  rm xcode-cli-tools.sh
else
  echo "CLI developer tools already installed."
fi

###############################################################################
# Install homebrew 
###############################################################################
if ! hash brew 2> /dev/null; then
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" </dev/null
fi

###############################################################################
# Install wget to download Virtualbox
###############################################################################
if ! hash wget 2> /dev/null; then
  brew install wget
fi

###############################################################################
# Install Virtualbox 
# (need to use wget not curl because of the 302)
# TODO: I am still getting asked for a password here.
###############################################################################
if ! hash vboxmanage 2> /dev/null; then
  wget http://download.virtualbox.org/virtualbox/4.3.26/VirtualBox-4.3.26-98988-OSX.dmg
  hdiutil mount VirtualBox-4.3.26-98988-OSX.dmg
  sudo installer -pkg /Volumes/VirtualBox/VirtualBox.pkg -target /
  sleep 2
  hdiutil unmount /Volumes/VirtualBox/
  rm VirtualBox-4.3.26-98988-OSX.dmg
fi

###############################################################################
# Install boot2docker
###############################################################################
if ! hash boot2docker 2> /dev/null; then
  brew install boot2docker
fi

###############################################################################
# Initialize Boot2Docker
###############################################################################
if ! boot2docker status; then
  boot2docker init
fi

###############################################################################
# Install ZSH and Oh-my-zsh
# You don't need this but I like it when working with this since while debugging this script
###############################################################################
if ! hash zsh 2> /dev/null; then
  echo "brew install zsh" > install_zsh.sh
  echo "curl -L https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh | sh" >> install_zsh.sh
fi

###############################################################################
# Install Paragon ExtFS
###############################################################################
if ! hash fsck_ufsd_ExtFS 2> /dev/null; then
  curl -O http://dl.paragon-software.com/demo/extmac_trial_u.dmg
  hdiutil attach extmac_trial_u.dmg
  sudo installer -pkg /Volumes/ParagonFS.localized/FSInstaller.app/Contents/Resources/Paragon\ ExtFS\ for\ Mac\ OS\ X.pkg -target /
  sleep 2
  hdiutil detach -force /Volumes/ParagonFS.localized
  rm extmac_trial_u.dmg
fi

###############################################################################
# Resize Disk
###############################################################################
# Did the user select USB, Usb, usb instead of a disk size?
INSTALL_TYPE=$(echo $1 | tr '[:upper:]' '[:lower:]')
if [ $INSTALL_TYPE  == "usb" ]; then
  # Detect the first USB disk
  USBDISK="NONE"
  for i in $(diskutil list | grep -E "[ ]+[0-9]+:.*disk[0-9]+" | sed 's/.*\(disk.*\)/\1/');
  do
   if diskutil info $i | grep -q "USB"; then 
     USBDISK=$i
     break
   fi
  done

  if [ $USBDISK  == "NONE" ]; then
    echo "No USB Disk found. Exiting"
    exit 1
  else
    echo USB DISK $USBDISK found.
    ROOTDISK=$USBDISK
    diskutil eraseDISK UFSD_EXTFS4 "1" $USBDISK
  fi

else
  # Resize MacOs drive to X gb and create ext4 volume
  # TODO: This could be improved to detect disks like we do with the USB above.
  if diskutil list ${ROOTDISK} | grep -q "Microsoft Basic Data"  ; then
    echo "Skipping disk resize and ext4 volume creation since already done."
  else
    sudo diskutil resizeVolume ${ROOTDISK}s2 ${1}g 1 UFSD_EXTFS4 "1" 0g
  fi
fi

# Get our ext4 volume. It should always be at disk0s4. But just in case.
EXT4VOL=$(diskutil list ${ROOTDISK} | grep "Microsoft Basic Data" | awk '{print $8}')

# Sanity Check
if echo $EXT4VOL | grep -q "${ROOTDISK}s"  ; then
  echo "Our ext4 volume is $EXT4VOL"
else
  echo "Could not find our ext4 volume. Try deleting all the volumes except Macintosh HD and restarting your computer."
  exit 1
fi

###############################################################################
# Setting up Virtual Disk to Physical Disk mapping
###############################################################################
# If boo2docker is already running then something went wrong and the user restarted the script
if ! [ "$(boot2docker status)" = "running" ] ; then

  echo "Setting up Virtual Disk to Physical Disk mapping"

  # Create some temp file names for our virtual disks.
  MAINDISK=`mktemp /tmp/main.vmdk.XXXXXX` || exit 1
  rm $MAINDISK

  # Make sure main disk is unmounted
  if [ -d /Volumes/1 ];
  then
    unmount $EXT4VOL
  fi

  sudo vboxmanage internalcommands createrawvmdk -filename $MAINDISK -rawdisk /dev/$EXT4VOL
  sudo chmod 777 $MAINDISK
  sudo chmod 777 /dev/$EXT4VOL
  vboxmanage storageattach boot2docker-vm --storagectl "SATA" --port 2 --device 0 --type hdd --medium $MAINDISK
  boot2docker up
fi

###############################################################################
# Get Boot2Docker exports
$(boot2docker shellinit)
###############################################################################

###############################################################################
# Generate system profile
# Generate system profile so we have information about this machine inside the VM
# If it exists as a directory delete it. (why does this keep getting created?)
###############################################################################
if [ -d ~/systeminfo.txt ];
then
  echo "Removing systeminfo.txt directory"
  rm -r ~/systeminfo.txt
fi

if [ ! -f ~/systeminfo.txt ];
then
  echo "Generating system profile"
  system_profiler -detailLevel mini > ~/systeminfo.txt
fi

###############################################################################
# Pull latest docker
# Not really needed for one time use but while working on the script it is nice.
###############################################################################
docker pull yantis/instant-archlinux-on-mac

###############################################################################
# Install rEFInd
###############################################################################
# Check if rEFInd already installed
if [ ! -d  /Volumes/ESP ]; then
  echo "Mounting EFI volume"
  sudo mkdir -p /Volumes/ESP
  sudo mount -t msdos /dev/${ROOTDISK}s1 /Volumes/ESP
fi

# # Remove rEFInd
# if [ -d  /Volumes/ESP/EFI/refind ]; then
#   echo "rEFInd installed uninstalling it."

#   # Delete rEFInd
#   sudo rm -rf /Volumes/ESP/EFI/refind
# fi

if [ -d  /Volumes/ESP/EFI/refind ]; then
  echo "rEFInd already installed so not reinstalling."

  unmount /Volumes/ESP
else

  if [ $INSTALL_TYPE  != "usb" ]; then
    unmount /Volumes/ESP
  fi

  # Install rEFInd
  # Just using my mirror since the sourceforge version is proving to be a pain in the ass
  # and you need to specify the exact mirror
  # curl - O http://downloads.sourceforge.net/project/refind/0.8.7/refind-bin-0.8.7.zip
  # sha256sum a5caefac0ba1691a5c958a4d8fdb9d3e14e223acd3b1605a5b0e58860d9d76b4  refind-bin-0.8.7.zip
  curl -O http://yantis-scripts.s3.amazonaws.com/refind-bin-0.8.7.zip
  unzip -o refind-bin-0.8.7.zip
  if [ $INSTALL_TYPE  == "usb" ]; then
    # (cd refind-bin-0.8.7 && sudo sh install.sh --alldrivers --usedefault /dev/${ROOTDISK}s1 )
    echo "Installing rEFInd to USB"
    mkdir -p  /Volumes/ESP/EFI
    cp -R refind-bin-0.8.7/refind /Volumes/ESP/EFI
    cp refind-bin-0.8.7/refind/refind.conf-sample /Volumes/ESP/EFI/refind/refind.conf

  else
    (cd refind-bin-0.8.7 && sudo sh install.sh --alldrivers)
  fi

  rm -r refind-bin-0.8.7
  rm refind-bin-0.8.7.zip

  # Sometimes rEFInd fails to unmount /Volumes/ESP so lets use that if its already open
  if [ ! -d  /Volumes/ESP ];
  then
    # sudo chmod 777 /dev/${ROOTDISK}s1
    sudo mkdir -p /Volumes/ESP
    sudo mount -t msdos /dev/${ROOTDISK}s1 /Volumes/ESP
  fi

  # Install the reFInd minimal theme if the user doesn't already have it installed
  # I moved this out of the docker container so it isn't as clean (ie: re-remounting etc)
  echo "Checking if rEFInd minimal theme is installed"

  if [ ! -d  /Volumes/ESP/EFI/refind/rEFInd-minimal ];
  then

    cd /Volumes/ESP/EFI/refind
    # You can pick different forks of this to your taste.
    git clone https://github.com/dylansm/rEFInd-minimal

    # Default is 128x128  Lets make it is 256x256 (still tiny on retina displays)
    sed -i.bak "s/#big_icon_size 256/big_icon_size 256/" refind.conf
    rm refind.conf.bak
    echo "include rEFInd-minimal/theme.conf" >> refind.conf

    # Leave or we can't unmount
    cd ~
  fi

  unmount /Volumes/ESP
fi

###############################################################################
# Even if we fail clean up what we can 
# so no more exits on errors from this point on.
###############################################################################
set +e

###############################################################################
# Run the container but make the script user definable as who knows what changes
# a user might want to make to the install script.
###############################################################################
docker run \
  --privileged \
  -v ~/systeminfo.txt:/systeminfo \
  -u root \
  --rm \
  -ti \
  yantis/instant-archlinux-on-mac \
  bash -c "run-remote-script https://raw.githubusercontent.com/yantis/instant-archlinux-on-mac/master/mac-install-internal.sh"

###############################################################################
# Take down the virtual machine
# Give the virtual machine time to clone otherwise we can not shut down. 
# 15 seconds is arbitrary but 5 or 10 sometimes isn't enough.
###############################################################################
sleep 15 
boot2docker down

###############################################################################
# Remove our physical harddrive from the boot2docker virtualmachine
###############################################################################
vboxmanage storageattach boot2docker-vm --storagectl "SATA" --port 2 --device 0 --type hdd --medium none

###############################################################################
# Remove our docker image
###############################################################################
# docker rmi yantis/instant-archlinux-on-mac

###############################################################################
# Restore security 
###############################################################################
sudo chmod 660 /dev/${ROOTDISK}s1
sudo sed -i.bak "s/Defaults timestamp_timeout=-1/#Defaults timestamp_timeout=-1/" /etc/sudoers

###############################################################################
# All Done 
###############################################################################
echo "DONE - REBOOT NOW TO USE ARCH LINUX."
read -p "Press [Enter] key to REBOOT or CTRL C to keep using Mac OSX"
sudo reboot

# vim:set ts=2 sw=2 et:
