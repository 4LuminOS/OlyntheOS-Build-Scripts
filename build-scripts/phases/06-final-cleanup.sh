#!/bin/bash
set -e

echo "--> Cleaning APT cache..."
apt-get clean
apt-get autoclean
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/archives/*

echo "--> Cleaning temporary files..."
rm -rf /tmp/*
rm -rf /var/tmp/*

echo "--> Cleaning system logs..."
find /var/log -type f -name "*.log" -delete
find /var/log -type f -name "*.gz" -delete
find /var/log -type f -name "*.1" -delete
truncate -s 0 /var/log/lastlog
truncate -s 0 /var/log/wtmp
truncate -s 0 /var/log/btmp

echo "--> Cleaning machine-id..."
truncate -s 0 /etc/machine-id
mkdir -p /var/lib/dbus
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id

echo "--> Cleaning bash history..."
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/liveuser/.bash_history
rm -f /home/*/.bash_history

echo "--> Cleaning journal logs..."
journalctl --vacuum=time=1d || true
journalctl --vacuum=size=10M || true

echo "--> Cleaning package manager cache..."
apt-get purge -y --auto-remove

echo "--> Cleaning systemd temp directories..."
rm -rf /var/lib/systemd/coredumps/*
rm -rf /run/log/journal/*

echo "--> Cleaning SSH keys (will regenerate on first boot)..."
rm -f /etc/ssh/ssh_host_*

echo "--> Cleaning udev rules cache..."
rm -rf /etc/udev/rules.d/.udevdb

echo "--> Cleaning misc caches..."
rm -rf /var/cache/fontconfig/*
rm -rf /var/cache/ldconfig/*

echo "--> Final ISO cleanup complete!"
