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
# since we don't actually modify the physical drive until the very end
###############################################################################
set -e -u -o pipefail

###############################################################################
# Get the model of this Mac/Macbook
###############################################################################
MODEL=$(grep "Model Identifier" /systeminfo | awk '{print $3}')
echo ""
echo "Mac Model: $MODEL"

###############################################################################
# Get the initial configuration file. Moved from inside the docker container
# To a URL so the user can change it to thier liking.
###############################################################################
wget -O /root/initial_configuration.sh \
  https://raw.githubusercontent.com/yantis/instant-archlinux-on-mac/master/initial_configuration.sh

###############################################################################
# A lot of this complexity is because of the error:
# mount: unknown filesystem type 'devtmpfs'
# Which only happens in docker container but not in a virtual machine.
# It would have been very nice to simply use pacstrap =(
###############################################################################
mkdir /arch
unsquashfs -d /squashfs-root /root/airootfs.sfs
ls /squashfs-root
mount -o loop /squashfs-root/airootfs.img /arch
mount -t proc none /arch/proc
mount -t sysfs none /arch/sys
mount -o bind /dev /arch/dev

# Important for pacman (for signature check)
# (Doesn't seem to matter at all they are still messed up.)
mount -o bind /dev/pts /arch/dev/pts

###############################################################################
# Use Google's nameservers though I believe we may be able to simply copy the
# /etc/resolv.conf over since Docker magages that and it "should" be accurate.
###############################################################################
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 8.8.8.4" >> /etc/resolv.conf
cp /etc/resolv.conf /arch/etc/resolv.conf

###############################################################################
# Generate entropy
###############################################################################
chroot /arch haveged

###############################################################################
# Init pacman
###############################################################################
# Fix for failed: IPC connect call failed
chroot /arch bash -c "dirmngr </dev/null > /dev/null 2>&1"
chroot /arch pacman-key --init
chroot /arch pacman-key --populate

###############################################################################
# Temp bypass sigchecks because of 
# GPGME error: Inapproropriate ioctrl for device
# It has something to do with the /dev/pts in a chroot but I didn't have any 
# luck solving it.
# https://bbs.archlinux.org/viewtopic.php?id=130538
###############################################################################
sed -i "s/\[core\]/\[core\]\nSigLevel = Never/" /arch/etc/pacman.conf
sed -i "s/\[extra\]/\[extra\]\nSigLevel = Never/" /arch/etc/pacman.conf
sed -i "s/\[community\]/\[community\]\nSigLevel = Never/" /arch/etc/pacman.conf

###############################################################################
# Enable multilib repo
###############################################################################
sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /arch/etc/pacman.conf
sed -i '/#\[multilib\]/,/#Include = \/etc\/pacman.d\/mirrorlist/ s/#//' /arch/etc/pacman.conf
sed -i 's/#\[multilib\]/\[multilib\]/g' /arch/etc/pacman.conf

###############################################################################
# Enable Infinality Fonts Repo
# Temp disable signature checking. But restore at the end.
# because of GPGME error: Inapproropriate ioctrl for device
###############################################################################
echo "[infinality-bundle-fonts]" >> /arch/etc/pacman.conf
echo "Server = http://bohoomil.com/repo/fonts" >>/arch/etc/pacman.conf
echo "SigLevel = Never" >> /arch/etc/pacman.conf

echo "[infinality-bundle]" >> /arch/etc/pacman.conf
echo "Server = http://bohoomil.com/repo/x86_64" >>/arch/etc/pacman.conf
echo "SigLevel = Never" >> /arch/etc/pacman.conf

echo "[infinality-bundle-multilib]" >> /arch/etc/pacman.conf
echo "Server = http://bohoomil.com/repo/multilib/x86_64" >> /arch/etc/pacman.conf
echo "SigLevel = Never" >> /arch/etc/pacman.conf

chroot /arch pacman-key -r 962DDE58 --keyserver hkp://subkeys.pgp.net
chroot /arch pacman-key --lsign 962DDE58

# For whatever reason when the system comes back up it won't remember these keys.
# So lets cache them and import them on first run.
chroot /arch mkdir -p /var/cache/keys
chroot /arch bash -c "pacman-key -e 962DDE58 > /var/cache/keys/962DDE58.pub"

###############################################################################
# Allow for colored output in pacman.conf
###############################################################################
sed -i "s/#Color/Color/" /arch/etc/pacman.conf

###############################################################################
# For now only uses mirrors.kernel.org as that is the most trusted mirror.
# So we do not run into a malicious mirror. 
# Will run reflector towards the end of the script.
###############################################################################
echo "Server = http://mirrors.kernel.org/archlinux/\$repo/os/\$arch" > /arch/etc/pacman.d/mirrorlist

###############################################################################
# Copy over general & custom cached packages
# Moved the packages to the docker container as I know the docker container 
# downloads trusted packages and it should be being build by a third party
# (docker hub) plus it avoids hammering the mirrors while working on this. 
# Plus it makes the install extremely fast.
###############################################################################
mkdir -p /arch/var/cache/pacman/general/

# Remove any development packages.
rm /var/cache/pacman/general/*devel*
rm /var/cache/pacman/general/*-dev-*

cp /var/cache/pacman/general/* /arch/var/cache/pacman/general/

mkdir -p /arch/var/cache/pacman/custom/
cp /var/cache/pacman/custom/* /arch/var/cache/pacman/custom/

###############################################################################
# Sync pacman database 
###############################################################################
chroot /arch pacman -Syy --noconfirm

###############################################################################
# Have pacman use aria2 for downloads and give it extreme patience
# This is mostly to keep the script from breaking on pacman timeout errors.
###############################################################################
chroot /arch bash -c "(cd /var/cache/pacman/general && pacman --noconfirm -U sqlite* aria2* c-ares*)"
echo "XferCommand = /usr/bin/printf 'Downloading ' && echo %u | awk -F/ '{printf \$NF}' && printf '...' && /usr/bin/aria2c -m99 -q --allow-overwrite=true -c --file-allocation=falloc --log-level=error --max-connection-per-server=2 --max-file-not-found=99 --min-split-size=5M --no-conf --remote-time=true --summary-interval=0 -t60 -d / -o %o %u && echo ' Complete!'" >> /etc/pacman.conf

###############################################################################
# Install general packages
###############################################################################
chroot /arch pacman --noconfirm --needed -U /var/cache/pacman/general/*.pkg.tar.xz

###############################################################################
# update after pushing packages from docker container to get the system 
# in the most up to date state.
###############################################################################
chroot /arch pacman -Su --noconfirm

###############################################################################
# Setup Infinality Fonts
# Moved to DOCKERFILE
###############################################################################
# chroot /arch pacman --noconfirm -Rdd freetype2 cairo fontconfig
# chroot /arch pacman --noconfirm --needed -S infinality-bundle
# # chroot /arch pacman --noconfirm --needed -S infinality-bundle-multilib

# # Instal fonts
# chroot /arch pacman --noconfirm -Rdd ttf-dejavu
# chroot /arch pacman --noconfirm --needed -S ibfonts-meta-base

# # Install ibfonts-meta-extended without the international fonts
# # If you want international its "ibfonts-meta-extended"
# chroot /arch pacman --noconfirm -Rdd cantarell-fonts
# chroot /arch pacman --noconfirm --needed -S \
#                       otf-cantarell-ib \
#                       ibfonts-meta-extended-lt \
#                       otf-oswald-ib \
#                       otf-quintessential-ib \
#                       otf-tex-gyre-ib \
#                       t1-cursor-ib \
#                       t1-urw-fonts-ib \
#                       ttf-caladea-ib \
#                       ttf-cantoraone-ib \
#                       ttf-carlito-ib \
#                       ttf-ddc-uchen-ib \
#                       ttf-droid-ib \
#                       ttf-gelasio-ib \
#                       ttf-lohit-odia-ib \
#                       ttf-lohit-punjabi-ib \
#                       ttf-merriweather-ib \
#                       ttf-merriweather-sans-ib \
#                       ttf-noto-serif-multilang-ib \
#                       ttf-opensans-ib \
#                       ttf-signika-family-ib \
#                       ttf-ubuntu-font-family-ib

###############################################################################
# Setup our initial_configuration service
###############################################################################
cp /root/initial_configuration.sh /arch/usr/lib/systemd/scripts/
cat >/arch/usr/lib/systemd/system/initial_configuration.service <<EOL
[Unit]
Description=One time Initialization

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/lib/systemd/scripts/initial_configuration.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOL

chmod +x /arch/usr/lib/systemd/scripts/initial_configuration.sh
chroot /arch systemctl enable initial_configuration.service

###############################################################################
# Increase the fontsize of the console. 
# On the new April 2015 12" Macbook I can not even read it.
###############################################################################
echo "FONT=ter-132n" >> /arch/etc/vconsole.conf


if [ $MODEL == "MacBook8,1" ]; then
  ###############################################################################
  # Experimental
  ###############################################################################
  sed -i "s/MODULES=\"\"/MODULES=\"ahci sd_mod libahci\"/" /arch/etc/mkinitcpio.conf

else
  ###############################################################################
  # ahci and sd_mod per this post: https://wiki.archlinux.org/index.php/MacBook
  sed -i "s/MODULES=\"\"/MODULES=\"ahci sd_mod\"/" /arch/etc/mkinitcpio.conf
  ###############################################################################
fi

###############################################################################
# Setup Intel GPU
###############################################################################
if grep -i -A1 "Intel" /systeminfo | grep -qi "GPU" ; then
  echo "Machine has an Intel graphics card."
  sed -i "s/MODULES=\"/MODULES=\"i915 /" /arch/etc/mkinitcpio.conf
  chroot /arch pacman --noconfirm --needed -U /var/cache/pacman/custom/xf86-video-intel*.pkg.tar.xz

  # http://loicpefferkorn.net/2015/01/arch-linux-on-macbook-pro-retina-2014-with-dm-crypt-lvm-and-suspend-to-disk/
  echo "options i915 enable_rc6=1 enable_fbc=1 lvds_downclock=1" >> /arch/etc/modprobe.d/i915.conf
fi

###############################################################################
# Setup AMD/ATI Radeon
###############################################################################
if grep -i -A1 "AMD" /systeminfo | grep -qi "GPU" ; then
  echo "Machine has an AMD/ATI graphics card."

  # Install drivers (opensource version)
  # chroot /arch pacman --noconfirm --needed -S xf86-video-ati
  # sed -i "s/MODULES=\"/MODULES=\"radeon /" /arch/etc/mkinitcpio.conf
  #   mkdir -p /arch/usr/share/X11/xorg.conf.d
  #   cat >/arch/usr/share/X11/xorg.conf.d/20-radeon.conf<<EOL
  #   Section "Device"
  #   Identifier "Radeon"
  #   Driver "radeon"
  #   EndSection
  # EOL

  # Can not get open source drivers to work on the Mac Retina so using Catalyst
  sed -i "s/MODULES=\"/MODULES=\"fglrx /" /arch/etc/mkinitcpio.conf

  # Blacklist the open source radeon module
  echo "install radeon /bin/false" >> /arch/etc/modprobe.d/blacklist.conf

  echo "[catalyst]" >> /arch/etc/pacman.conf
  echo "Server = http://catalyst.wirephire.com/repo/catalyst/\$arch" >> /arch/etc/pacman.conf

  # Add the catalyst repo key for later when we re-enable security
  chroot /arch pacman-key -r 653C3094 --keyserver hkp://subkeys.pgp.net
  chroot /arch pacman-key --lsign 653C3094

  # For whatever reason when the system comes back up it won't remember these keys.
  # So lets cache them and import them on first run.
  chroot /arch mkdir -p /var/cache/keys
  chroot /arch bash -c "pacman-key -e 653C3094 > /var/cache/keys/653C3094.pub"

  # I can't get the keys to work in the chroot in the docker container. TEMP disable.
  echo "SigLevel = Never" >> /arch/etc/pacman.conf

  # Sync the new catalyst database
  chroot /arch pacman -Sy

  # Install Catalyst drivers.
  chroot /arch pacman --noconfirm -Rdd mesa-libgl
  chroot /arch pacman --noconfirm --needed -S catalyst-hook
  chroot /arch pacman --noconfirm --needed -S catalyst-libgl

  # Update mkinitcpio with our catalyst hook
  OLDLINE=`grep "^HOOKS" /arch/etc/mkinitcpio.conf`
  NEWLINE=`echo ${OLDLINE} | sed -e "s/fsck/fsck fglrx/"`
  sed -i "s/${OLDLINE}/${NEWLINE}/" /arch/etc/mkinitcpio.conf

  chroot /arch systemctl enable catalyst-hook

  echo "AMD/ATI Installed"
fi

###############################################################################
# Setup NVIDIA
###############################################################################
if grep -i -A1 "NVIDIA" /systeminfo | grep -qi "GPU" ; then
  echo "Machine has an NVIDIA graphics card."

  # Install Nvidia drivers with automatic re-compilation of the NVIDIA module with kernel update 
  HOOKS="base udev autodetect modconf block filesystems keyboard fsck"

  # Uninstall mesa-libgl since it will conflict with nividia-libgl
  chroot /arch pacman --noconfirm -Rdd mesa-libgl

  # Install Nvidia DKMS and Utils 
  chroot /arch pacman --noconfirm --needed -U /var/cache/pacman/custom/nvidia-*-3*.pkg.tar.xz

  # Install Nvidia hook 
  chroot /arch pacman --noconfirm --needed -U /var/cache/pacman/custom/nvidia-hook*.pkg.tar.xz

  # Install Nvidia backlight stuff
  # dmesg says "No supported Nvidia graphics adapter found"
  # chroot /arch bash -c "pacman --noconfirm --needed -U /var/cache/pacman/custom/nvidia-bl-dkms*.pkg.tar.xz"

  # update mkinitcpio with our nvidia hook
  OLDLINE=`grep "^HOOKS" /arch/etc/mkinitcpio.conf`
  NEWLINE=`echo ${OLDLINE} | sed -e "s/fsck/fsck nvidia/"`
  sed -i "s/${OLDLINE}/${NEWLINE}/" /arch/etc/mkinitcpio.conf

  mkdir -p /arch/usr/share/X11/xorg.conf.d
  cat >/arch/usr/share/X11/xorg.conf.d/20-nvidia.conf<<EOL
  Section "Device"
  Identifier "Default Nvidia Device"
  Driver "nvidia"
  EndSection
EOL
  echo "Nvidia video drivers installed"
fi

###############################################################################
# Install the fan daemon
# TODO: The new macbook April 2015 is fanless so this might not work on that. Need to check.
###############################################################################
chroot /arch pacman --noconfirm --needed -U /var/cache/pacman/custom/mbpfan*.pkg.tar.xz

###############################################################################
# Powersaving 
# http://loicpefferkorn.net/2015/01/arch-linux-on-macbook-pro-retina-2014-with-dm-crypt-lvm-and-suspend-to-disk/
###############################################################################
echo "options snd_hda_intel power_save=1" >> /arch/etc/modprobe.d/snd_hda_intel.conf
echo "options usbcore autosuspend=1" >> /arch/etc/modprobe.d/usbcore.conf

###############################################################################
# Broadcom network drivers
###############################################################################
if grep -i -A1 "Broadcom" /systeminfo | grep -qi "MAC" ; then
  echo "Machine has an Broadcom network card."

  chroot /arch pacman --noconfirm --needed -U /var/cache/pacman/custom/broadcom-wl-dkms*.pkg.tar.xz

  # Install the Broadcom b43 firmware just in case the user needs it.
  # https://wiki.archlinux.org/index.php/Broadcom_wireless
  cp -R /firmware/* /arch/lib/firmware/
fi

###############################################################################
# Fix IRQ issues.
# https://wiki.archlinux.org/index.php/MacBook#Sound
###############################################################################
echo "options snd_hda_intel model=intel-mac-auto"  >> /arch/etc/modprobe.d/snd_hda_intel.conf

###############################################################################
# Generate locale (change this to yours if it is not US English)
###############################################################################
chroot /arch locale-gen en_US.UTF-8

###############################################################################
# Enable DKMS service
###############################################################################
chroot /arch systemctl enable dkms.service

###############################################################################
# Create new account that isn't root. user: user password: user
# You can and should change this later https://wiki.archlinux.org/index.php/Change_username
# Or just delete it and create another.
###############################################################################
chroot /arch useradd -m -g users -G wheel -s /bin/zsh user
chroot /arch bash -c "echo "user:user" | chpasswd"

# Mark users password as expired so user changes it from user/user
# User can't log into SDDM if I do this.
# chroot /arch chage -d 0 user

# allow passwordless sudo for our user
echo "user ALL=(ALL) NOPASSWD: ALL" >> /arch/etc/sudoers

###############################################################################
# Give it a host name 
###############################################################################
echo macbook > /arch/etc/hostname

###############################################################################
# Enable kernel modules for fan speed and the temperature sensors
###############################################################################
echo coretemp >> /arch/etc/modules
echo applesmc >> /arch/etc/modules

###############################################################################
# Enable Thermald 
###############################################################################
chroot /arch systemctl enable thermald

###############################################################################
# Enable cpupower and set governer to powersave
###############################################################################
chroot /arch systemctl enable cpupower

# works in a Linux docker container but not a mac boot2docker one
# Will run at initial startup.
# chroot /arch cpupower frequency-set -g powersave

###############################################################################
# Get latest Early 2015 13" - Version 12,x wireless lan firware otherwise it won't work.
###############################################################################
# https://wiki.archlinux.org/index.php/MacBook
(cd /arch/usr/lib/firmware/brcm/ && \
  curl -O https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/plain/brcm/brcmfmac43602-pcie.bin)

###############################################################################
# Force reinstall microkernel updates so they appear in boot.
###############################################################################
chroot /arch pacman -S --noconfirm intel-ucode

###############################################################################
# Setup rEFInd to boot up using Intel Micokernel updates
###############################################################################
# Hit F2 for these options
# UUID=$(lsblk -no UUID /dev/sdc) # Doesn't work in a docker container
UUID=$(blkid /dev/sdb -o export | grep UUID | head -1)

#if [ $MODEL == "MacBook8,1" ]; then
if [ $MODEL == "EXPERIMENTAL" ]; then
  echo "\"1\" \"root=$UUID rootfstype=ext4 rw i915.i915_enable_rc6=1 i915.i915_enable_fbc=1 i915.lvds_downclock=1 usbcore.autosuspend=1 h initrd=/boot/initramfs-linux.img\" " >> /arch/boot/refind_linux.conf
else
  # Normal setup which works fine.
  echo "\"Graphical Interface\" \"root=$UUID rootfstype=ext4 rw quiet loglevel=6 systemd.unit=graphical.target initrd=/boot/intel-ucode.img initrd=/boot/initramfs-linux.img\" " > /arch/boot/refind_linux.conf
  echo "\"Normal with microkernel updates\" \"root=$UUID rootfstype=ext4 rw loglevel=6 initrd=/boot/intel-ucode.img initrd=/boot/initramfs-linux.img\" " >> /arch/boot/refind_linux.conf
  echo "\"Normal without microkernel updates\" \"root=$UUID rootfstype=ext4 rw loglevel=6 initrd=/boot/initramfs-linux.img\" " >> /arch/boot/refind_linux.conf
  echo "\"Fallback with microkernel updates\" \"root=$UUID rootfstype=ext4 rw loglevel=6 initrd=/boot/intel-ucode.img initrd=/boot/initramfs-linux-fallback.img\" " >> /arch/boot/refind_linux.conf
  echo "\"Fallback without microkernel updates\" \"root=$UUID rootfstype=ext4 rw loglevel=6 initrd=/boot/initramfs-linux-fallback\" " >> /arch/boot/refind_linux.conf
fi

###############################################################################
# Setup fstab
# TODO look into not using discard. http://blog.neutrino.es/2013/howto-properly-activate-trim-for-your-ssd-on-linux-fstrim-lvm-and-dmcrypt/
###############################################################################
echo "$UUID / ext4 discard,rw,relatime,data=ordered 0 1" > /arch/etc/fstab
echo "efivarfs  /sys/firmware/efi/efivars efivarfs  rw,nosuid,nodev,noexec,relatime 0 0" >> /arch/etc/fstab
echo "LABEL=EFI /boot/EFI vfat  rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro  0 2" >> /arch/etc/fstab

###############################################################################
# Share our Mac drive with Arch Linux (though read only unless we disable journaling in Mac Os)
# https://support.apple.com/en-us/HT204435
# https://wiki.archlinux.org/index.php/MacBook
###############################################################################
mkdir -p /media/mac
echo "/dev/sda2    /media/mac     hfsplus auto,user,ro,exec   0 0" >> /arch/etc/fstab

###############################################################################
# Enable and setup SDDM Display Manger
###############################################################################
chroot /arch systemctl enable sddm
cat >/arch/etc/sddm.conf<<EOL
[Theme]
Current=archlinux
EOL

###############################################################################
# Enable network manager
###############################################################################
chroot /arch systemctl disable dhcpcd
chroot /arch systemctl enable NetworkManager.service

###############################################################################
# xfce4-terminal is my terminal of choice (for now)
# So set that up.
###############################################################################
mkdir -p /arch/home/user/.config/xfce4/terminal
cat >/arch/home/user/.config/xfce4/terminal/terminalrc <<EOL
[Configuration]
MiscAlwaysShowTabs=FALSE
MiscBell=FALSE
MiscBordersDefault=TRUE
MiscCursorBlinks=FALSE
MiscCursorShape=TERMINAL_CURSOR_SHAPE_BLOCK
MiscDefaultGeometry=100x40
MiscInheritGeometry=FALSE
MiscMenubarDefault=FALSE
MiscMouseAutohide=FALSE
MiscToolbarDefault=FALSE
MiscConfirmClose=TRUE
MiscCycleTabs=TRUE
MiscTabCloseButtons=TRUE
MiscTabCloseMiddleClick=TRUE
MiscTabPosition=GTK_POS_TOP
MiscHighlightUrls=TRUE
FontName=Liberation Mono for Powerline 14
ColorPalette=#000000000000;#cccc00000000;#4e4e9a9a0606;#c4c4a0a00000;#34346565a4a4;#757550507b7b;#060698989a9a;#d3d3d7d7cfcf;#555557575353;#efef29292929;#8a8ae2e23434;#fcfce9e94f4f;#73739f9fcfcf;#adad7f7fa8a8;#3434e2e2e2e2;#eeeeeeeeecec
TitleMode=TERMINAL_TITLE_REPLACE
ShortcutsNoMenukey=TRUE
ShortcutsNoMnemonics=TRUE
ScrollingLines=100000
EOL

# Disable F1 and F10 in the terminal so I can use my function keys to move around tmux panes
cat >/arch/home/user/.config/xfce4/terminal/accels.scm <<EOL
(gtk_accel_path "<Actions>/terminal-window/fullscreen" "")
(gtk_accel_path "<Actions>/terminal-window/contents" "")
EOL

###############################################################################
# Install the xf86-input-mtrack package
#
# The defaults are way to fast for my taste.
# Config is here: https://github.com/BlueDragonX/xf86-input-mtrack
# Config I am trying is from : https://help.ubuntu.com/community/MacBookPro11-1/utopic
###############################################################################
# Mac Retina doesn't have a trackpad
if [[ $MODEL == *"MacBook"* ]]
then
  chroot /arch pacman --noconfirm --needed -U /var/cache/pacman/custom/xf86-input-mtrack*.pkg.tar.xz
  cat >/arch/usr/share/X11/xorg.conf.d/10-mtrack.conf <<EOL
  Section "InputClass"
  MatchIsTouchpad "on"
  Identifier "Touchpads"
  Driver "mtrack"
  Option "Sensitivity" "0.7"
  Option "IgnoreThumb" "true"
  Option "ThumbSize" "50"
  Option "IgnorePalm" "true"
  Option "DisableOnPalm" "false"
  Option "BottomEdge" "30"
  Option "TapDragEnable" "true"
  Option "Sensitivity" "0.6"
  Option "FingerHigh" "3"
  Option "FingerLow" "2"
  Option "ButtonEnable" "true"
  Option "ButtonIntegrated" "true"
  Option "ButtonTouchExpire" "750"
  Option "ClickFinger1" "1"
  Option "ClickFinger2" "3"
  Option "TapButton1" "1"
  Option "TapButton2" "3"
  Option "TapButton3" "2"
  Option "TapButton4" "0"
  Option "TapDragWait" "100"
  Option "ScrollLeftButton" "7"
  Option "ScrollRightButton" "6"
  Option "ScrollDistance" "100"
  EndSection
EOL

  # Enable natural scrolling
  echo "pointer = 1 2 3 5 4 6 7 8 9 10 11 12" > /arch/home/user/.Xmodmap
else
  # Install mouse drivers.
  pacman -S --noconfirm --needed xf86-input-mouse
fi

###############################################################################
# Copy over the mac system info in case we need it for something in the future.
###############################################################################
cp /systeminfo /arch/systeminfo.txt

###############################################################################
# Disable autologin for root
###############################################################################
cat >/arch/etc/systemd/system/getty@tty1.service.d/override.conf<<EOL
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noclear %I 38400 linux
EOL

###############################################################################
# Setup Awesome Tiling Windows Manager
###############################################################################
chroot /arch pacman --noconfirm --needed -S awesome vicious
chroot /arch mkdir -p /home/user/.config/awesome/themes/default
chroot /arch cp /etc/xdg/awesome/rc.lua /home/user/.config/awesome
chroot /arch cp -rf /usr/share/awesome/themes/default \
                    /home/user/.config/awesome/themes/
chroot /arch sed -i "s/beautiful.init(\"\/usr\/share\/awesome\/themes\/default\/theme.lua\")/beautiful.init(awful.util.getdir(\"config\") .. \"\/themes\/default\/theme.lua\")/" \
                  /home/user/.config/awesome/rc.lua
chroot /arch sed -i "s/xterm/xfce4-terminal/" /home/user/.config/awesome/rc.lua
# chroot /arch sed -i "s/nano/vim/" /home/user/.config/awesome/rc.lua
chroot /arch sed -i '1s/^/vicious = require("vicious")\n/' \
                  /home/user/.config/awesome/rc.lua

###############################################################################
# Setup oh-my-zsh
###############################################################################
chroot /arch cp /usr/share/oh-my-zsh/zshrc /home/user/.zshrc
chroot /arch sed -i "s/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"bullet-train\"/" \
  /home/user/.zshrc
chroot /arch sed -i "s/plugins=(git)/plugins=(git git-extras pip tmux python rsync cp archlinux node npm history-substring-search)/" \
  /home/user/.zshrc
echo "BULLETTRAIN_CONTEXT_SHOW=\"true\"" >> /arch/home/user/.zshrc
echo "BULLETTRAIN_CONTEXT_BG=\"31\"" >> /arch/home/user/.zshrc
echo "BULLETTRAIN_CONTEXT_FG=\"231\"" >> /arch/home/user/.zshrc

###############################################################################
# Update mlocate
###############################################################################
chroot /arch updatedb

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# Final things before syncing to the physical drive.
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

###############################################################################
# Create initial ramdisk enviroment. 
###############################################################################
chroot /arch mkinitcpio -p linux

# New Macbook Retina April 2015 Release
# if [ $MODEL == "MacBook8,1" ]; then
#   chroot /arch pacman --noconfirm -S linux-lts
#   chroot /arch mkinitcpio -p linux-lts
# fi

###############################################################################
# Rank mirrors by speed and only use https mirrors
# Sometimes the mirrors page is down so this would break the script so
# lets give it up to five minutes before timing out.
###############################################################################
timeout=$(($(date +%s) + 360))
until \
  chroot /arch reflector \
  --verbose \
  -l 10 \
  --protocol https \
  --sort rate \
  --save /etc/pacman.d/mirrorlist \
  2>/dev/null || [[ $(date +%s) -gt $timeout ]]; do
  :
done

###############################################################################
# Delete the arch user
###############################################################################
echo "Deleting arch user."
chroot /arch userdel -rf arch

###############################################################################
# Move any general or custom packages into the pacman cache
###############################################################################
echo "Moving any general or custom packages into pacman cache"
mv /arch/var/cache/pacman/general/* /arch/var/cache/pacman/pkg/
mv /arch/var/cache/pacman/custom/* /arch/var/cache/pacman/pkg/

###############################################################################
# Update databases
# Not exactly sure what yaourt is doing that pacman isn't but 
# pacman -Syy won't update everyting if the packages changed
# TODO: See /usr/lib/yaourt/*.sh
###############################################################################
echo "Updating Databases"
chroot /arch runuser -l user -c "yaourt -Syy"

###############################################################################
# Restore pacman's security
###############################################################################
echo "Restoring pacman's security"
chroot /arch sed -i "s/SigLevel = Never/#SigLevel = Never/g" /etc/pacman.conf

###############################################################################
# Lets make sure that any config files etc our user has full ownership of.
###############################################################################
chroot /arch chown -R user:users /home/user/

###############################################################################
# Fix for: https://bugs.archlinux.org/task/42798
# Otherwise pacman can not look up the keys remotely.
# TODO confirm I do not need to do this on first run
###############################################################################
# chroot /arch  pacman-key --populate archlinux

###############################################################################
# Re-Import any keys we imported above.
# We already did this above but for some reason we need to do it now or it
# there will be db issues with pacman when ran.
###############################################################################
# chroot /arch pacman-key -r 962DDE58 --keyserver hkp://subkeys.pgp.net
# chroot /arch pacman-key --lsign 962DDE58
# chroot /arch pacman-key -r AE6866C7962DDE58 --keyserver hkp://subkeys.pgp.net
# chroot /arch pacman-key --lsign AE6866C7962DDE58

# if grep -i -A1 "AMD" /systeminfo | grep -qi "GPU" ; then
#   chroot /arch pacman-key -r 653C3094 --keyserver hkp://subkeys.pgp.net
#   chroot /arch pacman-key --lsign 653C3094
# fi
# chroot /arch pacman-key -u

###############################################################################
# Force root user to change password on next login.
###############################################################################
chroot /arch chage -d 0 root

#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
# UP TO THIS POINT WE HAVE NOT ACTUALLY MODIFIED THE USERS SYSTEM
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

###############################################################################
# Mount the physical drive 
###############################################################################
mkdir /mnt/archlinux
mount /dev/sdb /mnt/archlinux

###############################################################################
# Sync to the physical drive
#
# On very slow USBs docker can time out This has only happened on one USB
# drive so far and appears to be more of a boot2docker issue than anything else.
###############################################################################
echo "Syncing system to your drive. This will take a couple minutes. (or significantly longer if using USB)"

time rsync -aAX --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} /arch/* /mnt/archlinux

# Not sure if this is needed but to be safe.
sync

###############################################################################
# Unmount physical drive
###############################################################################
# delay before unmount to finish writing.otherwise sometimes in use.
sleep 2

# Unmount main disk
umount /mnt/archlinux

###############################################################################
# TODO LIST
###############################################################################
# Powertop
# Virtulbox VM of Archlinux on the Mac side
# Shared volume
# Encrypted user partition
# Suspend to disk
# Consider zram/zswap https://wiki.archlinux.org/index.php/Maximizing_performance
# Looks like a ton of goodies in helmuthdu's script. https://github.com/helmuthdu/aui
# Reverse Engineer iMac Retina's 5K. I notice that with rEFInd installed it defaults to 4k.
# - Possible this can solve that: https://github.com/0xbb/apple_set_os.efi
echo "*** FINISHED ***"

# vim:set ts=2 sw=2 et:
