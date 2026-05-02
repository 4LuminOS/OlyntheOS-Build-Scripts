#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "--> CUSTOMIZING DESKTOP (Theme, Transparency, Cursor)..."

# Clean Bloat
apt-get purge -y kmahjongg kmines kpat ksnake kmail kontact akregator || true
apt-get autoremove -y

echo "--> Generating Configs..."
CONFIG_TMP="/tmp/luminos-configs"
mkdir -p "$CONFIG_TMP/.config"

# 1. Dark Theme
cat > "$CONFIG_TMP/.config/kdeglobals" << "EOF"
[General]
ColorScheme=BreezeDark
Name=BreezeDark
[Icons]
Theme=Papirus-Dark
EOF

# 2. Modern Cursor (Nécessite script 08)
cat > "$CONFIG_TMP/.config/kcminputrc" << "EOF"
[Mouse]
cursorTheme=DMZ-White
cursorSize=24
EOF

# 3. Wallpaper & Transparency
cat > "$CONFIG_TMP/.config/plasma-org.kde.plasma.desktop-appletsrc" << "EOF"
[Containments][1]
wallpaperplugin=org.kde.image

[Containments][1][Wallpaper][org.kde.image][General]
Image=file:///usr/share/wallpapers/luminos/luminos-wallpaper-default.png
FillMode=2

[Containments][1][General]
panelOpacity=1
EOF

# 4. SDDM Theme
mkdir -p /etc/sddm.conf.d/
cat > /etc/sddm.conf.d/luminos-theme.conf << "EOF"
[Theme]
Current=breeze
[General]
Background=/usr/share/wallpapers/luminos/luminos-sddm-background.png
EOF

# --- APPLY TO USERS ---
cp -r "$CONFIG_TMP/.config" /etc/skel/

if id "liveuser" &>/dev/null; then
    echo "--> Injecting into liveuser..."
    HOMEDIR="/home/liveuser"
    mkdir -p "$HOMEDIR/.config"
    cp -r "$CONFIG_TMP/.config/." "$HOMEDIR/.config/"
    chown -R liveuser:liveuser "$HOMEDIR"
fi

rm -rf "$CONFIG_TMP"
echo "--> Desktop Customization Complete."
rm -rf "$CONFIG_TMP"

echo "SUCCESS: Desktop environment ready and applied."
