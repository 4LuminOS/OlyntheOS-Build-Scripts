#!/bin/bash
set -e

echo "--> INSTALLING SOFTWARE (Zen Browser & Tools)..."

# 1. Base Tools & UI Assets
# We add ‘jq’ to parse the GitHub API properly.
apt-get update
apt-get install -y \
    htop \
    w3m \
    curl \
    wget \
    unzip \
    bzip2 \
    vlc \
    jq \
    dmz-cursor-theme \
    papirus-icon-theme

# 2. ZEN BROWSER INSTALLATION (Dynamic Fetch)
echo "--> Detecting latest Zen Browser..."
mkdir -p /opt/zen-browser

# We ask the GitHub API for the exact URL of the tar.bz2 file for Linux.
ZEN_API_URL="https://api.github.com/repos/zen-browser/desktop/releases/latest"
ZEN_DOWNLOAD_URL=$(curl -s "$ZEN_API_URL" | jq -r '.assets[] | select(.name | contains("linux-x86_64.tar.bz2")) | .browser_download_url' | head -n 1)

if [ -n "$ZEN_DOWNLOAD_URL" ] && [ "$ZEN_DOWNLOAD_URL" != "null" ] && \
   [[ "$ZEN_DOWNLOAD_URL" =~ ^https://github\.com/zen-browser/desktop/releases/ ]]; then
    echo "--> Downloading Zen from: $ZEN_DOWNLOAD_URL"
    wget -O /tmp/zen.tar.bz2 "$ZEN_DOWNLOAD_URL"
    
    echo "--> Extracting Zen..."
    tar -xjf /tmp/zen.tar.bz2 -C /opt/zen-browser --strip-components=1
    ln -sf /opt/zen-browser/zen /usr/local/bin/zen-browser
    
    # Shortcut (.desktop)
    cat > /usr/share/applications/zen-browser.desktop <<EOF
[Desktop Entry]
Name=Zen Browser
Comment=Experience tranquility
Exec=zen-browser %u
Icon=/opt/zen-browser/browser/chrome/icons/default/default128.png
Terminal=false
Type=Application
Categories=Network;WebBrowser;
StartupNotify=true
EOF

    # Set as default
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/zen-browser 200
    update-alternatives --set x-www-browser /usr/local/bin/zen-browser
    
    rm -f /tmp/zen.tar.bz2
    echo "--> Zen Browser installed successfully."

else
    echo "WARNING: Could not find Zen Browser asset. Falling back to Firefox"
    apt-get install -y firefox-esr
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox-esr 200
fi

echo "--> Software installation complete."
