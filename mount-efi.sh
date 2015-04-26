#!/bin/bash
if [ ! -d  /Volumes/ESP ]; then
  echo "Mounting EFI volume"
  sudo mkdir -p /Volumes/ESP
  sudo mount -t msdos /dev/disk0s1 /Volumes/ESP
fi
