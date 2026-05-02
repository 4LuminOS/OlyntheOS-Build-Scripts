#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
echo "--> Installing Linux kernel, GRUB, and firmware..."
apt-get install -y linux-image-amd64 grub-pc firmware-amd-graphics
echo "--> Installing KDE Plasma desktop and services..."
DESKTOP_PACKAGES="plasma-desktop konsole sddm network-manager"
apt-get install -y $DESKTOP_PACKAGES
