#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
echo "--> Configuring APT sources..."
# (live-build already did that, but we make sure)
echo "--> Updating package lists and upgrading system..."
apt-get update && apt-get -y upgrade
echo "--> Setting hostname to LuminOS..."
echo "LuminOS" > /etc/hostname
echo "--> Setting timezone to Europe/Zurich..."
ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime
echo "--> Configuring locales..."
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
apt-get install -y locales
locale-gen
update-locale LANG="en_US.UTF-8"
echo "--> Creating live user 'liveuser'..."
useradd -m -s /bin/bash -G sudo,audio,video,netdev,plugdev liveuser
echo "--> Setting default passwords to 'luminos'..."
# SECURITY NOTE: These are intentional live-ISO defaults for demo use only.
# Both accounts use the published default password 'luminos'.
# Any production or persistent installation MUST change these passwords immediately.
echo "root:luminos" | chpasswd
echo "liveuser:luminos" | chpasswd
