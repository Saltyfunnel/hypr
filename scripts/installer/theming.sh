#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

log_message "Installation started for theming section"
print_info "\nStarting theming setup..."

# Install required packages for SDDM QML themes
run_command "pacman -S --noconfirm qt6-svg qt6-declarative qt5-quickcontrols2" "Install Qt dependencies for SDDM themes" "yes"

# Install nwg-look for GTK theme management
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes" 

# Install Qt5, Qt6 Settings, and Kvantum theme engines
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt5, Qt6 Settings, and Kvantum theme engines" "yes"

# Extract Catppuccin GTK theme
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes"

# Extract Catppuccin icon theme
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"

# Install Kvantum Catppuccin theme from AUR
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin theme for Kvantum" "yes" "no"

# Copy Kitty terminal Catppuccin config
run_command "cp -r /home/$SUDO_USER/hypr/configs/kitty /home/$SUDO_USER/.config/" "Copy Catppuccin theme configuration for Kitty terminal" "yes" "no"

# Install LasseDorre's Catppuccin SDDM theme
run_command "git clone https://github.com/LasseDorre/xdg-sddm-catppuccin.git /tmp/xdg-catppuccin-sddm" "Clone LasseDorre's Catppuccin SDDM theme repository" "yes"
run_command "sudo mkdir -p /usr/share/sddm/themes" "Ensure SDDM themes directory exists" "yes"
run_command "sudo cp -r /tmp/xdg-catppuccin-sddm/catppuccin-mocha /usr/share/sddm/themes/" "Copy Catppuccin SDDM theme to SDDM themes folder" "yes"
run_command "sudo chown -R root:root /usr/share/sddm/themes/catppuccin-mocha" "Set correct ownership for Catppuccin SDDM theme" "yes"

# Set Catppuccin as the current SDDM theme
run_command "sudo bash -c 'echo -e \"[Theme]\\nCurrent=catppuccin-mocha\" > /etc/sddm.conf'" "Set Catppuccin as current SDDM theme" "yes"

print_info "\nPost-installation instructions:"
print_bold_blue "Set themes and icons:"
echo "   - Run 'nwg-look' and set the global GTK and icon theme"
echo "   - Open 'kvantummanager' (run with sudo for system-wide changes) to select and apply the Catppuccin theme"
echo "   - Open 'qt6ct' to set the icon theme"
echo "   - Your SDDM login screen should now use the Catppuccin theme"

echo "------------------------------------------------------------------------"
