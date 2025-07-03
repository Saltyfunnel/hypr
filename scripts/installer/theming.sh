#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

log_message "Installation started for theming section"
print_info "\nStarting theming setup..."

# Install nwg-look for GTK theme management
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes"

# Install Qt theme engines
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt5, Qt6 Settings, and Kvantum theme engines" "yes"

# Install Catppuccin GTK theme
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes"

# Install Tela Circle Dracula icon theme
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"

# Install Catppuccin Kvantum theme from AUR
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin theme for Kvantum" "yes" "no"

# Copy Kitty terminal theme config
run_command "cp -r /home/$SUDO_USER/hypr/configs/kitty /home/$SUDO_USER/.config/" "Copy Catppuccin theme configuration for Kitty terminal" "yes" "no"

# Install Catppuccin SDDM theme from local assets folder
run_command "sudo cp -r /home/$SUDO_USER/hypr/assets/themes/catmochasddm /usr/share/sddm/themes/" "Copy Catppuccin SDDM theme to SDDM themes folder" "yes"
run_command "sudo chown -R root:root /usr/share/sddm/themes/catmochasddm" "Set correct ownership for Catppuccin SDDM theme" "yes"

# Set Catppuccin as the current SDDM theme
run_command "sudo bash -c 'echo -e \"[Theme]\\nCurrent=catmochasddm\" > /etc/sddm.conf'" "Set Catppuccin as current SDDM theme" "yes"

# Post-installation instructions
print_info "\nPost-installation instructions:"
print_bold_blue "Set themes and icons:"
echo "   - Run 'nwg-look' and set the global GTK and icon theme"
echo "   - Open 'kvantummanager' (run with sudo for system-wide changes) to select and apply the Catppuccin theme"
echo "   - Open 'qt6ct' to set the icon theme"
echo "   - SDDM should now use the Catppuccin theme on login"

echo "------------------------------------------------------------------------"
