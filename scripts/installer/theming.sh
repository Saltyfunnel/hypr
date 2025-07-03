#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source "$SCRIPT_DIR/helper.sh"

log_message "Installation started for theming section"
print_info "\nStarting theming setup..."

# Install GTK and Qt theming tools
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes"
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt5, Qt6 Settings, and Kvantum theme engines" "yes"

# Install Nautilus so it respects GTK themes
run_command "pacman -S --noconfirm nautilus" "Install Nautilus file manager (GTK-based)" "yes"

# Ensure assets directory exists before copying
run_command "mkdir -p /home/$SUDO_USER/.config/assets" "Create assets config directory" "no" "no"
run_command "cp -r /home/$SUDO_USER/simple-hyprland/assets/* /home/$SUDO_USER/.config/assets/" "Copy assets (themes, wallpapers, SDDM themes)" "yes" "no"

# Install GTK and icon themes
run_command "tar -xvf /home/$SUDO_USER/.config/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes"
run_command "tar -xvf /home/$SUDO_USER/.config/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"

# Install Kvantum Catppuccin theme
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin theme for Kvantum" "yes" "no"

# Copy Kitty config
run_command "cp -r /home/$SUDO_USER/simple-hyprland/configs/kitty /home/$SUDO_USER/.config/" "Copy Catppuccin theme configuration for Kitty terminal" "yes" "no"

# Install Qt dependencies and SDDM theme
run_command "pacman -S --noconfirm qt6-svg qt6-declarative qt5-quickcontrols2" "Install Qt dependencies for SDDM theme" "yes"
run_command "cp -r /home/$SUDO_USER/.config/assets/themes/catmochasddm /usr/share/sddm/themes/" "Copy Catppuccin SDDM theme to system" "yes"

# Set the SDDM theme
if [ -f "/etc/sddm.conf" ]; then
    sed -i '/^Current=/d' /etc/sddm.conf
    echo "[Theme]" >> /etc/sddm.conf
    echo "Current=catmochasddm" >> /etc/sddm.conf
    log_message "Set Catppuccin SDDM theme in /etc/sddm.conf"
else
    mkdir -p /etc
    echo -e "[Theme]\nCurrent=catmochasddm" > /etc/sddm.conf
    log_message "Created /etc/sddm.conf and set Catppuccin SDDM theme"
fi

# Final guidance
print_info "\nPost-installation instructions:"
print_bold_blue "Set themes and icons:"
echo "   - Run 'nwg-look' to set GTK and icon themes"
echo "   - Run 'kvantummanager' (as user or sudo) to apply Kvantum themes"
echo "   - Use 'qt5ct' and 'qt6ct' to apply icons and fonts for Qt apps"
echo "   - Restart Nautilus or reboot for theme changes to take full effect"

echo "------------------------------------------------------------------------"
