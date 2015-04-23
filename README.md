Instant Arch Linux on Macs & Macbooks

This will setup Arch Linux on your Mac/MacBook all from Mac OSX. No need for any USB drives or figuring out the proper network drivers to get your
system to get up. It should install without any rebooting etc. Just launch it and enter your password twice and go about your business.

Warning: Backup your stuff or use a fresh Macbook. There are no guarantees this will work and it might leave your machine in an unusable 
state. I personally didn't worry about this to much as you can just reset it back to a [factory restore]
(https://github.com/yantis/instant-archlinux-on-mac/blob/master/factory-restore.md) with "⌘ + R" at startup 
or "option + ⌘  + R for [internet recovery](https://github.com/yantis/instant-archlinux-on-mac/blob/master/factory-restore.md).

Will this work with your iMac or MacBook? Possibly. It worked with all the ones I tested it with. I suspect it will most likely work and even if not perfect
you will be in a much better place than trying to do it by hand. I do know for a fact that I haven't set it up to work with fusion drives yet
so if your drive is a fusion drive it won't work without some minor changes.

# Testing

## Tested Working
* Mountain Lion, Lion, Yosimite
* [MacBookPro10,1] - Macbook Pro Retina 17" 2013
* [MacBookPro10,2] - Macbook Pro Retina 15" 2013
* [iMac15,1] - iMac Retina 2014

## Tested not working but in progress
* [MacBook8,1] - Macbook 12" April 2015 (Setup works but so far no one that I know has any version of linux on one of these. If you do please let me know so I can fix it)


# Setup
* Make sure FileVault encryption is turned off. If it isn't you need to disable it and reboot.
* Use ⌘ + space to open spotlight. Type in terminal and hit return.
* Optionally, update your software either through the the terminal or app store  Though if you do you may have to reboot though probably not.
This step can take a while on a new machine. It usually is a 2+ GB download. You simply might want to use the GUI update application to have some indication of progress.
```
sudo softwareupdate -i -a
```



### Factory purchased.
* If you just purchased the Macbook you should be good to go. Just make sure you do not have Filevault on and you are not
using the  Apple Core Storage volume manager (if it is check out [this thread](http://awesometoast.com/yosemite-core-storage-and-partition-woes/)
to set it to HFS+).

The defaults look like this. This script expects your "Macintosh HD" to be at disk0s2.

```
$ diskutil list

/dev/disk0
#:                       TYPE NAME                    SIZE       IDENTIFIER
0:      GUID_partition_scheme                        *500.3 GB   disk0
1:                        EFI EFI                     209.7 MB   disk0s1
2:                  Apple_HFS Macintosh HD            499.4 GB   disk0s2
3:                 Apple_Boot Recovery HD             650.0 MB   disk0s3
```

* Update the software. This is important as the only way to get firmware updates. Type the below and enter your password.
This can take a while if this is a new machine. You might actually think it locked up. It just takes a while
depending on your bandwidth. You simply might want to use the GUI update application to have some indication of progress.
(Note: maybe do this last. I found that I could not open up any more GUI apps without a reboot)
Though also maybe it may overwrite the EFI stuff. so maybe needs to go first

```
sudo softwareupdate -i -a
```

# References

### Mac on Archlinux 
http://loicpefferkorn.net/2015/01/arch-linux-on-macbook-pro-retina-2014-with-dm-crypt-lvm-and-suspend-to-disk/
https://wiki.archlinux.org/index.php/MacBook
https://bbs.archlinux.org/viewtopic.php?id=195924
https://github.com/pandeiro/arch-on-air
https://github.com/jantman/puppet-archlinux-macbookretina
https://github.com/search?utf8=%E2%9C%93&q=arch+linux+macbook
https://wiki.debian.org/iMacIntel
https://github.com/coldnew/macbookair-2013-config/blob/master/kernel-config.example
https://github.com/NapoleonWils0n/cerberus/blob/6e224ff0b3677fce7c78ee7db15095c68e7a1ea7/arch-linux/arch-linux-macair.sh
https://github.com/gammy/macbook8-1_archlinux
https://wiki.archlinux.org/index.php/MacBook
http://loicpefferkorn.net/2015/01/arch-linux-on-macbook-pro-retina-2014-with-dm-crypt-lvm-and-suspend-to-disk/
https://medium.com/@PhilPlckthun/arch-linux-running-on-my-macbook-2ea525ebefe3
https://help.ubuntu.com/community/MacBookPro11-1/utopic
https://github.com/jantman/puppet-archlinux-macbookretina
http://www.nixknight.com/2014/02/arch-linux-installation-with-kde-desktop/
https://github.com/pandeiro/arch-on-air

### Creating/Resizing of MacOS drives
http://apple.stackexchange.com/questions/63130/create-new-partition-in-unallocated-space-with-diskutil
https://github.com/cowboy/dotfiles/blob/master/bin/osx_hide_partition
http://en.wikipedia.org/wiki/GUID_Partition_Table

### Homebrew
http://brew.sh/

### Docker
http://blog.javabien.net/2014/03/03/setup-docker-on-osx-the-no-brainer-way/
http://viget.com/extend/how-to-use-docker-on-os-x-the-missing-guide

### EXT4
https://github.com/carlcarl/blog/blob/cacca2e50fe4fbcca2e9c3d68bad9176a66f8016/content/archive/osx_mavericks_ext4.md
http://download.paragon-software.com/doc/Manual_extfsmac_eng.pdf
http://www.paragon-software.com/home/extfs-mac/download.html
https://jamfnation.jamfsoftware.com/discussion.html?id=12843
http://tips.jay.cat/ext4-support-in-osx-yosemite/

### EFI
http://www.rodsbooks.com/refind/installing.html#wde

### VirtualBox
https://wiki.archlinux.org/index.php/VirtualBox

### SquashFS
http://askubuntu.com/questions/95392/how-to-create-a-bootable-system-with-a-squashfs-root
