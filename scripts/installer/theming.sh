#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

log_message "Installation started for theming section"
print_info "\nStarting theming setup..."

# Create persistent assets folder outside repo for wallpapers, icons, themes, etc.
run_command "mkdir -p /home/$SUDO_USER/.config/assets" "Create persistent assets folder" "no" "no"

# Copy assets from repo to persistent folder
run_command "cp -r $SCRIPT_DIR/assets/* /home/$SUDO_USER/.config/assets/" "Copy assets to persistent location" "yes" "no"

# Install nwg-look for GTK theme management
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes"

# Install Qt5/6 theme engines and Kvantum
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt theme engines and Kvantum" "yes"

# Install Catppuccin Mocha GTK theme
run_command "tar -xvf /home/$SUDO_USER/.config/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes"

# Install Tela Circle Dracula icon theme
run_command "tar -xvf /home/$SUDO_USER/.config/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"

# Install Catppuccin Kvantum theme from AUR
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin Kvantum theme" "yes" "no"

# Copy Kitty config with Catppuccin theme
run_command "cp -r $SCRIPT_DIR/configs/kitty /home/$SUDO_USER/.config/" "Copy Catppuccin Kitty config" "yes" "no"

# Post-install instructions
print_info "\nPost-installation instructions:"
print_bold_blue "Set themes and icons:"
echo "   - Run 'nwg-look' and set the global GTK and icon theme."
echo "   - Open 'kvantummanager' (use sudo for system-wide changes) to select and apply the Catppuccin Kvantum theme."
echo "   - Open 'qt6ct' to set the icon theme."

echo "------------------------------------------------------------------------"
