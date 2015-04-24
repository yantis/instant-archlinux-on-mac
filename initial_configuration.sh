#!/bin/bash

#==============================================================================
#==============================================================================
#         Copyright (c) 2015 Jonathan Yantis
#               yantis@yantis.net
#          Released under the MIT license
#==============================================================================
#==============================================================================

###############################################################################
# Change this to your timezone
###############################################################################
timedatectl set-timezone America/Los_Angeles

###############################################################################
# Set the keyboard LEDs to light up
# change this to 0 or your desired brightness level
###############################################################################
echo "255" > /sys/class/leds/smc::kbd_backlight/brightness

###############################################################################
# Set this to your desired cpu power mode.
###############################################################################
if hash cpupower 2> /dev/null; then
# cpupower frequency-set -g performance
cpupower frequency-set -g powersave
fi

###############################################################################
# NVIDIA
# If the machine has an nvidia card then run nvidia-xconfig on it
###############################################################################
if hash nvidia-xconfig 2> /dev/null; then
  nvidia-xconfig \
    --add-argb-glx-visuals \
    --allow-glx-with-composite \
    --composite \
    -no-logo \
    --render-accel \
    -o /usr/share/X11/xorg.conf.d/20-nvidia.conf
fi

###############################################################################
# AMD/ATI
# If the machine has an AMD/ATI card then run aticonfig on it
###############################################################################
if hash aticonfig 2> /dev/null; then
  aticonfig \
    --initial \
    --output /usr/share/X11/xorg.conf.d/20-radeon.conf
fi

###############################################################################
# Setup Sound
# By default ALSA has all channels muted. Those have to be unmuted manually
###############################################################################
amixer sset Master unmute

###############################################################################
# Cleanup
# This is supposed to delete us but it still is around as I see a fragment in the journal
###############################################################################
sytemctl disable initial_configuration.service
rm /usr/lib/systemd/system/initial_configuration.service
rm $0
