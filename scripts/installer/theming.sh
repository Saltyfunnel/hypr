#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

log_message "Installation started for theming section"
print_info "\nStarting theming setup..."

# Install theme engines and theming tools
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes"
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum kvantum-qt5" "Install Qt5, Qt6 Settings, and Kvantum theme engines" "yes"
run_command "pacman -S --noconfirm qt6-svg qt6-declarative qt5-quickcontrols2" "Install Qt dependencies for SDDM themes" "yes"

# Install GTK theme
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes"

# Install icon theme
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"

# Install Kvantum Catppuccin theme
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin theme for Kvantum" "yes" "no"

# Copy Kitty theme config
run_command "cp -r /home/$SUDO_USER/hypr/configs/kitty /home/$SUDO_USER/.config/" "Copy Catppuccin Kitty theme config" "yes" "no"

# 🧊 Install Catppuccin SDDM theme
run_command "git clone https://github.com/catppuccin/sddm.git /tmp/catppuccin-sddm" "Clone Catppuccin SDDM theme" "yes"
run_command "mkdir -p /usr/share/sddm/themes/catppuccin-mocha" "Create SDDM theme directory" "no"
run_command "cp -r /tmp/catppuccin-sddm/src/* /usr/share/sddm/themes/catppuccin-mocha" "Install Catppuccin SDDM theme to /usr/share/sddm/themes" "no"

# 🛠️ Safely configure /etc/sddm.conf
print_info "Setting SDDM theme in /etc/sddm.conf..."
if [ ! -f /etc/sddm.conf ]; then
    echo -e "[Theme]\nCurrent=catppuccin-mocha" > /etc/sddm.conf
else
    if grep -q "^\[Theme\]" /etc/sddm.conf; then
        sed -i '/^\[Theme\]/,/^\[.*\]/ s/^Current=.*/Current=catppuccin-mocha/' /etc/sddm.conf || \
        echo "Current=catppuccin-mocha" >> /etc/sddm.conf
    else
        echo -e "\n[Theme]\nCurrent=catppuccin-mocha" >> /etc/sddm.conf
    fi
fi
log_message "Set SDDM theme to catppuccin-mocha"

# 🧾 Final instructions
print_info "\nPost-installation instructions:"
print_bold_blue "🧩 Set themes and icons manually if needed:"
echo "   - Run 'nwg-look' to apply GTK and icon themes"
echo "   - Run 'kvantummanager' to apply the Kvantum theme"
echo "   - Run 'qt5ct' or 'qt6ct' to set Qt icon themes"
echo "   - Reboot or logout to see SDDM login screen theme"

echo "------------------------------------------------------------------------"
