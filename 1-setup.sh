#!/usr/bin/env bash
echo -ne "
-------------------------------------------------------------------------
   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
-------------------------------------------------------------------------
"
source setup.conf
echo -ne "
-------------------------------------------------------------------------
                    Network Setup 
-------------------------------------------------------------------------
"
pacman -S networkmanager dhclient --noconfirm --needed
systemctl enable --now NetworkManager
echo -ne "
-------------------------------------------------------------------------
                    Setting up mirrors for optimal download 
-------------------------------------------------------------------------
"
pacman -S --noconfirm pacman-contrib curl
pacman -S --noconfirm reflector rsync
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak

nc=$(grep -c ^processor /proc/cpuinfo)
echo -ne "
-------------------------------------------------------------------------
                    You have " $nc" cores. And
			changing the makeflags for "$nc" cores. Aswell as
				changing the compression settings.
-------------------------------------------------------------------------
"
TOTALMEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
if [[  $TOTALMEM -gt 8000000 ]]; then
sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" /etc/makepkg.conf
sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" /etc/makepkg.conf
fi
echo -ne "
-------------------------------------------------------------------------
                    Setup Language to US and set locale  
-------------------------------------------------------------------------
"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
timedatectl --no-ask-password set-timezone ${timezone}
timedatectl --no-ask-password set-ntp 1
localectl --no-ask-password set-locale LANG="en_US.UTF-8" LC_TIME="en_US.UTF-8"

# Set keymaps
localectl --no-ask-password set-keymap ${keymap}

# Add sudo no password rights
sed -i 's/^# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers

#Add parallel downloading
sed -i 's/^#Para/Para/' /etc/pacman.conf

#Enable multilib
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
pacman -Sy --noconfirm
echo -ne "
-------------------------------------------------------------------------
                    Installing Base System  
-------------------------------------------------------------------------
"
sudo pacman -S --noconfirm --needed - < /pkg-files/pacman-pkgs.txt
echo -ne "
-------------------------------------------------------------------------
                    Installing Microcode
-------------------------------------------------------------------------
"
# determine processor type and install microcode
proc_type=$(lscpu | awk '/Vendor ID:/ {print $3}')
case "$proc_type" in
	GenuineIntel)
		print "Installing Intel microcode"
		pacman -S --noconfirm intel-ucode
		proc_ucode=intel-ucode.img
		;;
	AuthenticAMD)
		print "Installing AMD microcode"
		pacman -S --noconfirm amd-ucode
		proc_ucode=amd-ucode.img
		;;
esac
echo -ne "
-------------------------------------------------------------------------
                    Installing Graphics Drivers
-------------------------------------------------------------------------
"
# Graphics Drivers find and install
# if lspci | grep -E "NVIDIA|GeForce"; then
#     pacman -S nvidia --noconfirm --needed
# 	nvidia-xconfig
# elif lspci | grep -E "Radeon"; then
#     pacman -S xf86-video-amdgpu --noconfirm --needed
if lspci | grep -E "Integrated Graphics Controller"; then
    pacman -S libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils --needed --noconfirm
fi
echo -ne "
-------------------------------------------------------------------------
                    Adding User
-------------------------------------------------------------------------
"
if [ $(whoami) = "root"  ]; then
    useradd -m -G wheel,libvirt -s /bin/bash $username 
# use chpasswd to enter $username:$password
    echo "$username:$password" | chpasswd
	cp -R /root/$SCRIPTHOME /home/$username/
    chown -R $username: /home/$username/$SCRIPTHOME
# enter $hostname to /etc/hostname
	echo $hostname > /etc/hostname
else
	echo "You are already a user proceed with aur installs"
fi
if [[ ${FS} == "luks" ]]; then
# Making sure to edit mkinitcpio conf if luks is selected
# add encrypt in mkinitcpio.conf before filesystems in hooks
    sed -i 's/filesystems/encrypt filesystems/g' /etc/mkinitcpio.conf
# making mkinitcpio with linux kernel
    mkinitcpio -p linux
fi
echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 2-user.sh
-------------------------------------------------------------------------
"
