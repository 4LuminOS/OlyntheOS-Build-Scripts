#!/bin/bash
set -e

echo "--> Installing Plymouth..."
apt-get install -y plymouth

echo "--> Setting up LuminOS theme directory..."
THEME_DIR="/usr/share/plymouth/themes/luminos"
# CRITICAL FIX: Create the directory first
mkdir -p "$THEME_DIR"

# Retrieve the logo (build.sh put assets in /usr/share/wallpapers/luminos)
if [ -f "/usr/share/wallpapers/luminos/logo-plymouth.png" ]; then
    echo "--> Copying logo to theme folder..."
    cp "/usr/share/wallpapers/luminos/logo-plymouth.png" "$THEME_DIR/logo.png"
else
    echo "ERROR: Logo not found at /usr/share/wallpapers/luminos/logo-plymouth.png"
    exit 1
fi

echo "--> Creating theme configuration files..."
cat > "${THEME_DIR}/luminos.plymouth" << EOF
[Plymouth Theme]
Name=LuminOS
Description=A clean and simple boot splash for LuminOS
ModuleName=script

[script]
ImageDir=${THEME_DIR}
ScriptFile=${THEME_DIR}/luminos.script
EOF

cat > "${THEME_DIR}/luminos.script" << EOF
logo_image = Image("logo.png");
logo_sprite = Sprite(logo_image);
logo_sprite.SetX(Window.GetWidth() / 2 - logo_image.GetWidth() / 2);
logo_sprite.SetY(Window.GetHeight() / 2 - logo_image.GetHeight() / 2 - 100);

progress_box_image = Image.Box(Window.GetWidth() / 4, 8, 0, 0, 0);
progress_box_sprite = Sprite(progress_box_image);
progress_box_sprite.SetX(Window.GetWidth() / 2 - progress_box_image.GetWidth() / 2);
progress_box_sprite.SetY(logo_sprite.GetY() + logo_image.GetHeight() + 50);

fun refresh_callback () {
  progress = Plymouth.GetProgress();
  progress_image = Image.Box(Window.GetWidth() / 4 * progress, 8, 1, 1, 1);
  progress_sprite = Sprite(progress_image);
  progress_sprite.SetX(Window.GetWidth() / 2 - progress_box_image.GetWidth() / 2);
  progress_sprite.SetY(logo_sprite.GetY() + logo_image.GetHeight() + 50);
}
Plymouth.SetRefreshFunction(refresh_callback);
EOF

echo "--> Applying theme..."
plymouth-set-default-theme -R luminos
update-initramfs -u

echo "SUCCESS: Plymouth theme installed."
