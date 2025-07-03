#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

log_message "Installation started for theming section"
print_info "\nStarting theming setup..."

# Install theming tools
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes"
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt5, Qt6 Settings, and Kvantum theme engines" "yes"

# Install Catppuccin GTK theme
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes"

# Install Tela Circle Dracula icon theme
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"

# Install Catppuccin Kvantum theme
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin theme for Kvantum" "yes" "no"

# Copy Kitty config with Catppuccin theme
run_command "cp -r /home/$SUDO_USER/hypr/configs/kitty /home/$SUDO_USER/.config/" "Copy Catppuccin theme configuration for Kitty terminal" "yes" "no"

# Copy all assets (backgrounds, lockscreen, wlogout assets, etc.)
USER_ASSETS_DIR="/home/$SUDO_USER/.config/assets"
mkdir -p "$USER_ASSETS_DIR"

ASSETS_SRC="/home/$SUDO_USER/hypr/assets"
if [ -d "$ASSETS_SRC" ]; then
    run_command "cp -r $ASSETS_SRC/* $USER_ASSETS_DIR/" "Copy all assets (backgrounds, lockscreen, etc.) to persistent location" "no" "no"
else
    print_warning "Assets folder not found at $ASSETS_SRC. Skipping asset copy."
    log_message "Assets folder missing, skipped copying assets."
fi

# === SDDM THEME SETUP ===

SDDM_THEME_NAME="catmochasddm"   # Update to your SDDM theme folder name
SDDM_THEME_SRC="/home/$SUDO_USER/hypr/assets/themes/$SDDM_THEME_NAME"
SDDM_THEME_DEST="/usr/share/sddm/themes/$SDDM_THEME_NAME"

if [ -d "$SDDM_THEME_SRC" ]; then
    print_info "\nSetting up SDDM theme: $SDDM_THEME_NAME"

    run_command "sudo cp -r $SDDM_THEME_SRC $SDDM_THEME_DEST" "Copy SDDM theme folder" "no"
    run_command "sudo chown -R root:root $SDDM_THEME_DEST" "Set ownership of SDDM theme folder" "no"
    run_command "sudo chmod -R 755 $SDDM_THEME_DEST" "Set permissions of SDDM theme folder" "no"

    # Ensure sddm.conf.d directory exists
    run_command "sudo mkdir -p /etc/sddm.conf.d" "Ensure sddm.conf.d directory exists" "no"

    # Write theme config snippet for SDDM
    echo -e "[Theme]\nCurrent=$SDDM_THEME_NAME" | sudo tee /etc/sddm.conf.d/00-$SDDM_THEME_NAME.conf > /dev/null
    log_message "SDDM theme config written to /etc/sddm.conf.d/00-$SDDM_THEME_NAME.conf"

    print_success "SDDM theme $SDDM_THEME_NAME installed and configured."
else
    print_warning "SDDM theme source folder not found: $SDDM_THEME_SRC. Skipping SDDM theme setup."
    log_message "SDDM theme folder missing, skipped SDDM theme installation."
fi

# Add instructions to configure theming
print_info "\nPost-installation instructions:"
print_bold_blue "Set themes and icons:"
echo "   - Run 'nwg-look' and set the global GTK and icon theme"
echo "   - Open 'kvantummanager' (run with sudo for system-wide changes) to select and apply the Catppuccin theme"
echo "   - Open 'qt6ct' to set the icon theme"
echo "   - Reboot or restart the sddm service to see the new login theme"

echo "------------------------------------------------------------------------"
