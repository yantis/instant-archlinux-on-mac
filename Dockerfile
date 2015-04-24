############################################################
# Copyright (c) 2015 Jonathan Yantis
# Released under the MIT license
############################################################

# ├─yantis/archlinux-tiny
#    ├─yantis/archlinux-small
#       ├─yantis/archlinux-mac-installer

# Dockerhub can not handle uploading layers above 500MB
# The layers time out on upload. Also, if a single RUN command
# takes to long to run Dockerhub will fail to build it so
# breaking them down into smaller chunks even if more redundant.

FROM yantis/archlinux-small
MAINTAINER Jonathan Yantis <yantis@yantis.net>

ADD run-remote-script.sh /bin/run-remote-script

###############################################################################
# Install permanent additions to the container.
###############################################################################
    # Force a refresh of all the packages even if already up to date.
RUN pacman --noconfirm -Syyu && \

    # Make our run remote script exectutable
    chmod +x /bin/run-remote-script && \

    # Remove the texinfo-fake package since we are installing perl for rsync.
    pacman --noconfirm -Rdd texinfo-fake && \

    # Install stuff we will need later
    pacman --noconfirm --needed -S \
            perl \
            texinfo \
            rsync \
            squashfs-tools && \

    # Clean up to make this as small as possible
    localepurge && \

    # Remove info, man and docs (only in this container.. not on our new install)
    rm -r /usr/share/info/* && \
    rm -r /usr/share/man/* && \

    # Delete any backup files like /etc/pacman.d/gnupg/pubring.gpg~
    find /. -name "*~" -type f -delete && \

    # Clean up pacman
    bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
    paccache -rk0 >/dev/null 2>&1 &&  \
    pacman-optimize && \
    rm -r /var/lib/pacman/sync/*

###############################################################################
# Build what we need for the Arch Linux install.
# As well as add in any temp stuff for building which we will remove later.
###############################################################################
RUN pacman --needed --noconfirm -Sy \
            base-devel \
            dkms \
            git \
            linux \
            linux-headers \
            yaourt && \

    # extract the firmware for the b43 (even if the user doesn't need it. It doesn't hurt)
    # https://wiki.archlinux.org/index.php/Broadcom_wireless
    pacman --noconfirm -S b43-fwcutter && \
    curl -LO http://downloads.openwrt.org/sources/broadcom-wl-4.178.10.4.tar.bz2 && \
    tar xjf broadcom-wl-4.178.10.4.tar.bz2 && \
    mkdir /firmware && \
    b43-fwcutter -w /firmware broadcom-wl-4.178.10.4/linux/wl_apsta.o && \
    rm -r broadcom-wl* && \
    pacman --noconfirm -R b43-fwcutter && \

    # create custom cache locations
    mkdir -p /var/cache/pacman/custom && \
    mkdir -p /var/cache/pacman/general && \

    # Build & cache xf86-input-mtrack-git package
    wget -P /tmp https://aur.archlinux.org/packages/xf/xf86-input-mtrack-git/xf86-input-mtrack-git.tar.gz && \
    tar -xvf /tmp/xf86-input-mtrack-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/xf86-input-mtrack-git && \
    runuser -l docker -c "(cd /tmp/xf86-input-mtrack-git && makepkg -sc --noconfirm)" && \
    mv /tmp/xf86-input-mtrack-git/*.xz /var/cache/pacman/custom/ && \

    # Build & cache thermald package
    wget -P /tmp https://aur.archlinux.org/packages/th/thermald/thermald.tar.gz && \
    tar -xvf /tmp/thermald.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/thermald && \
    runuser -l docker -c "(cd /tmp/thermald && makepkg -sc --noconfirm)" && \
    mv /tmp/thermald/*.xz /var/cache/pacman/general/ && \

    # Build & cache nvidia-bl-dkms package
    wget -P /tmp https://aur.archlinux.org/packages/nv/nvidia-bl-dkms/nvidia-bl-dkms.tar.gz && \
    tar -xvf /tmp/nvidia-bl-dkms.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/nvidia-bl-dkms && \
    runuser -l docker -c "(cd /tmp/nvidia-bl-dkms && makepkg -sc --noconfirm)" && \
    mv /tmp/nvidia-bl-dkms/*.xz /var/cache/pacman/custom/ && \

    ## NVIDIA START##
    # build and cache stuff needed for nvidia
    pacman --noconfirm -S nvidia nvidia-utils && \

    # build and cache nvidia-dkms package
    wget -P /tmp https://aur.archlinux.org/packages/nv/nvidia-dkms/nvidia-dkms.tar.gz && \
    tar -xvf /tmp/nvidia-dkms.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/nvidia-dkms && \
    runuser -l docker -c "(cd /tmp/nvidia-dkms && makepkg -sc --noconfirm)" && \
    mv /tmp/nvidia-dkms/*.xz /var/cache/pacman/custom/ && \
    rm -r /tmp/* && \

    # Remove Nvidia so we can install nvidia-dkms
    pacman --noconfirm -Rdd nvidia && \

    # Install Nvidia DKMS
    pacman --noconfirm -U /var/cache/pacman/custom/nvidia-dkms* && \

    # build and cache nvidia-hook package
    wget -P /tmp https://aur.archlinux.org/packages/nv/nvidia-hook/nvidia-hook.tar.gz && \
    tar -xvf /tmp/nvidia-hook.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/nvidia-hook && \
    runuser -l docker -c "(cd /tmp/nvidia-hook && makepkg -sc --noconfirm)" && \
    mv /tmp/nvidia-hook/*.xz /var/cache/pacman/custom/ && \
    rm -r /tmp/* && \

    # Remove Nvidia utils/dkms from the system since we do not need them anymore.
    pacman --noconfirm -Rs \
            nvidia-utils \
            nvidia-dkms && \

    # Remove nvidia drivers since dkms replaces them.
    rm /var/cache/pacman/pkg/nvidia-3* && \

    # Move utils to the custom directory to be installed with nvidia dkms & hook
    mv /var/cache/pacman/pkg/nvidia-utils* /var/cache/pacman/custom/ && \
    ## NVIDIA END##

    # build and cache mbpfan-git package
    wget -P /tmp https://aur.archlinux.org/packages/mb/mbpfan-git/mbpfan-git.tar.gz && \
    tar -xvf /tmp/mbpfan-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/mbpfan-git && \
    runuser -l docker -c "(cd /tmp/mbpfan-git && makepkg -sc --noconfirm)" && \
    mv /tmp/mbpfan-git/*.xz /var/cache/pacman/custom/ && \
    rm -r /tmp/*  && \

    # Download broadcom and intel drivers.
    pacman --noconfirm -Sw --cachedir /var/cache/pacman/custom \
            broadcom-wl-dkms \
            xf86-video-intel && \

    # Download and cache Liberation TTF Mono Powerline Fonts
    wget -P /tmp https://aur.archlinux.org/packages/tt/ttf-liberation-mono-powerline-git/ttf-liberation-mono-powerline-git.tar.gz && \
    tar -xvf /tmp/ttf-liberation-mono-powerline-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/ttf-liberation-mono-powerline-git && \
    runuser -l docker -c "(cd /tmp/ttf-liberation-mono-powerline-git && makepkg -sc --noconfirm)" && \
    mv /tmp/ttf-liberation-mono-powerline-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache oh-my-zsh
    wget -P /tmp https://aur.archlinux.org/packages/oh/oh-my-zsh-git/oh-my-zsh-git.tar.gz && \
    tar -xvf /tmp/oh-my-zsh-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/oh-my-zsh-git && \
    runuser -l docker -c "(cd /tmp/oh-my-zsh-git && makepkg -sc --noconfirm)" && \
    mv /tmp/oh-my-zsh-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache bullet-train-oh-my-zsh-theme-git
    wget -P /tmp https://aur.archlinux.org/packages/bu/bullet-train-oh-my-zsh-theme-git/bullet-train-oh-my-zsh-theme-git.tar.gz && \
    tar -xvf /tmp/bullet-train-oh-my-zsh-theme-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/bullet-train-oh-my-zsh-theme-git && \
    runuser -l docker -c "(cd /tmp/bullet-train-oh-my-zsh-theme-git && makepkg -sc --noconfirm)" && \
    mv /tmp/bullet-train-oh-my-zsh-theme-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache fasd
    wget -P /tmp https://aur.archlinux.org/packages/fa/fasd-git/fasd-git.tar.gz && \
    tar -xvf /tmp/fasd-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/fasd-git && \
    runuser -l docker -c "(cd /tmp/fasd-git && makepkg -sc --noconfirm)" && \
    mv /tmp/fasd-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache zsh-dwim-git
    wget -P /tmp https://aur.archlinux.org/packages/zs/zsh-dwim-git/zsh-dwim-git.tar.gz && \
    tar -xvf /tmp/zsh-dwim-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/zsh-dwim-git && \
    runuser -l docker -c "(cd /tmp/zsh-dwim-git && makepkg -sc --noconfirm)" && \
    mv /tmp/zsh-dwim-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # Download and cache zaw
    wget -P /tmp https://aur.archlinux.org/packages/za/zaw-git/zaw-git.tar.gz && \
    tar -xvf /tmp/zaw-git.tar.gz -C /tmp && \
    chown -R docker:docker /tmp/zaw-git && \
    runuser -l docker -c "(cd /tmp/zaw-git && makepkg -sc --noconfirm)" && \
    mv /tmp/zaw-git/*.xz /var/cache/pacman/general/ && \
    rm -r /tmp/* && \

    # # AWS Command Line Tools
    # runuser -l docker -c "yaourt --noconfirm -S aws-cli" && \

    # ## Download and cache python-jmespath
    # wget -P /tmp https://aur.archlinux.org/packages/py/python-jmespath/python-jmespath.tar.gz && \
    # tar -xvf /tmp/python-jmespath.tar.gz -C /tmp && \
    # chown -R docker:docker /tmp/python-jmespath && \
    # runuser -l docker -c "(cd /tmp/python-jmespath && makepkg -sc --noconfirm)" && \
    # mv /tmp/python-jmespath/*.xz /var/cache/pacman/general/ && \
    # rm -r /tmp/* && \

    # ## Download and cache python-botocore
    # wget -P /tmp https://aur.archlinux.org/packages/py/python-botocore/python-botocore.tar.gz && \
    # tar -xvf /tmp/python-botocore.tar.gz -C /tmp && \
    # chown -R docker:docker /tmp/python-botocore && \
    # runuser -l docker -c "(cd /tmp/python-botocore && makepkg -sc --noconfirm)" && \
    # mv /tmp/python-botocore/*.xz /var/cache/pacman/general/ && \
    # rm -r /tmp/* && \

    # ## Download and cache python-bcdoc
    # wget -P /tmp https://aur.archlinux.org/packages/py/python-bcdoc/python-bcdoc.tar.gz && \
    # tar -xvf /tmp/python-bcdoc.tar.gz -C /tmp && \
    # chown -R docker:docker /tmp/python-bcdoc && \
    # runuser -l docker -c "(cd /tmp/python-bcdoc && makepkg -sc --noconfirm)" && \
    # mv /tmp/python-bcdoc/*.xz /var/cache/pacman/general/ && \
    # rm -r /tmp/* && \

    # ## Download and cache python-colorama
    # wget -P /tmp https://aur.archlinux.org/packages/py/python-colorama-0.2.5/python-colorama-0.2.5.tar.gz && \
    # tar -xvf /tmp/python-colorama-0.2.5.tar.gz -C /tmp && \
    # chown -R docker:docker /tmp/python-colorama-0.2.5 && \
    # runuser -l docker -c "(cd /tmp/python-colorama-0.2.5 && makepkg -sc --noconfirm)" && \
    # mv /tmp/python-colorama-0.2.5/*.xz /var/cache/pacman/general/ && \
    # rm -r /tmp/* && \

    # ## Download and cache aws-cli
    # wget -P /tmp https://aur.archlinux.org/packages/aw/aws-cli/aws-cli.tar.gz && \
    # tar -xvf /tmp/aws-cli.tar.gz -C /tmp && \
    # chown -R docker:docker /tmp/aws-cli && \
    # runuser -l docker -c "(cd /tmp/aws-cli && makepkg -sc --noconfirm)" && \
    # mv /tmp/aws-cli/*.xz /var/cache/pacman/general/ && \
    # rm -r /tmp/* && \

    # # Remove the awc-cli we used for building the above
    # runuser -l docker -c "yaourt --noconfirm -Rs aws-cli" && \

    # Remove anything just needed for the AWS Tools install.
    # pacman --noconfirm -Rs python python-setuptools

    # Remove anything we added that we do not need
    pacman --noconfirm -Rs dbus-glib dri2proto dri3proto fontsproto glproto \
            libxml2 libxss mesa pixman presentproto randrproto renderproto flex \
            resourceproto videoproto xf86driproto xineramaproto xorg-util-macros \
            linux dkms gcc linux-headers binutils guile make libxfont xorg-bdftopcf \
            xorg-font-utils fontconfig xorg-fonts-encodings libtool m4 git inputproto \
            dbus systemd yaourt package-query automake libx32-flex bison autoconf \
            automake1.11 freetype2 harfbuzz graphite libpng xorg-server-devel \
            libunistring gettext && \

    # Clean up to make this as small as possible
    localepurge && \

    # Remove info, man and docs (only in this container.. not on our new install)
    rm -r /usr/share/info/* && \
    rm -r /usr/share/man/* && \
    rm -r /usr/share/doc/* && \

    # Delete any backup files like /etc/pacman.d/gnupg/pubring.gpg~
    find /. -name "*~" -type f -delete && \

    # Clean up pacman
    bash -c "echo 'y' | pacman -Scc >/dev/null 2>&1" && \
    paccache -rk0 >/dev/null 2>&1 &&  \
    pacman-optimize && \
    rm -r /var/lib/pacman/sync/*

###############################################################################
# Cache packages that have happened since the last airootfs image
# Purposely add another layer here to break up the size.
# Since we kept the one above clean it should add minimal overhead.
###############################################################################
RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            btrfs-progs \
            ca-certificates-utils \
            ca-certificates \
            dnsmasq \
            glib2 \
            glibc \
            grml-zsh-config \
            gssproxy \
            lftp \
            libinput \
            libssh2 \
            libtasn1 \
            lz4 \
            man-pages \
            nano \
            ntp \
            partclone \
            openconnect \
            systemd-sysvcompat \
            tcpdump \
            testdisk && \
    rm -r /var/lib/pacman/sync/*

###############################################################################
# Just download these since we don't actually need them for the docker container.
# Make sure none of these are in the list above.
###############################################################################
RUN pacman --noconfirm -Syw --cachedir /var/cache/pacman/general \
            base-devel \
            acpi \
            alsa-utils \
            arch-install-scripts \
            aria2 \
            awesome \
            c-ares \
            cpupower \
            ctags \
            dkms \
            feh \
            git \
            haveged \
            htop \
            gnome-keyring \
            google-chrome \
            hfsprogs \
            intel-ucode \
            imagemagick \
            linux \
            linux-headers \
            lm_sensors \
            mlocate \
            networkmanager \
            network-manager-applet \
            pavucontrol \
            package-query \
            pciutils \
            pekwm \
            plasma \
            powertop \
            pulseaudio \
            pulseaudio-alsa \
            python-dateutil \
            python-docutils \
            python-pyasn1\
            python-rsa \
            python-setuptools \
            python-six \
            reflector \
            rsync \
            sqlite \
            sddm \
            systemd \
            terminus-font \
            tree \
            tmux \
            vicious \
            vim \
            xfce4 \
            xfce4-whiskermenu-plugin \
            xorg-server \
            xorg-server-utils \
            xorg-xinit \
            xorg-xev \
            yajl \
            yaourt \
            zsh-syntax-highlighting && \
    rm -r /var/lib/pacman/sync/*
