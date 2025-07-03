#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

log_message "Installation started for theming section"
print_info "\n🎨 Starting theming setup..."

# 1. GTK, Icons, Qt, Kvantum
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes"

run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt5, Qt6 Settings, and Kvantum theme engines" "yes"

run_command "tar -xvf /home/$SUDO_USER/hypr/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes"

run_command "tar -xvf /home/$SUDO_USER/hypr/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"

run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin Kvantum theme" "yes" "no"

run_command "cp -r /home/$SUDO_USER/hypr/configs/kitty /home/$SUDO_USER/.config/" "Copy Kitty terminal config" "yes" "no"

# 2. SDDM Catppuccin Theme Setup
print_info "\n✨ Installing Catppuccin SDDM theme..."

# Dependencies
run_command "pacman -S --noconfirm qt6-svg qt6-declarative qt5-quickcontrols2" "Install SDDM theme Qt dependencies" "yes"

# Clone and move theme
run_command "git clone https://github.com/catppuccin/sddm.git /tmp/catppuccin-sddm" "Clone Catppuccin SDDM theme repo" "no" "no"

run_command "mkdir -p /usr/share/sddm/themes/catppuccin-mocha && cp -r /tmp/catppuccin-sddm/src/* /usr/share/sddm/themes/catppuccin-mocha" "Copy Catppuccin theme to SDDM theme directory" "no"

# Permissions
run_command "chown -R root:root /usr/share/sddm/themes/catppuccin-mocha" "Fix permissions on SDDM theme" "no"

# Apply theme in sddm.conf
SDDM_CONF="/etc/sddm.conf"
if [ ! -f "$SDDM_CONF" ]; then
    echo "[Theme]" > $SDDM_CONF
    echo "Current=catppuccin-mocha" >> $SDDM_CONF
else
    sed -i '/^\[Theme\]/,/^\[/ s/^Current=.*/Current=catppuccin-mocha/' $SDDM_CONF || echo -e "\n[Theme]\nCurrent=catppuccin-mocha" >> $SDDM_CONF
fi
log_message "Set SDDM theme to catppuccin-mocha in $SDDM_CONF"
print_success "✅ Catppuccin SDDM theme applied."

# 3. Post instructions
print_info "\nPost-installation instructions:"
print_bold_blue "Set themes and icons manually if needed:"
echo "   - Run 'nwg-look' to set GTK and icon theme"
echo "   - Run 'kvantummanager' to select the Kvantum Catppuccin theme"
echo "   - Run 'qt6ct' to select the icon theme"
echo "   - Reboot to verify SDDM theme appearance"

echo "------------------------------------------------------------------------"
