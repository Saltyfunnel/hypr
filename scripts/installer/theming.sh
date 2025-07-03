#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source "$SCRIPT_DIR/helper.sh"

log_message "Installation started for theming section"
print_info "\nStarting theming setup..."

# Install nwg-look (GTK theme manager)
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes" "yes"

# Install Qt5/6 theme engines and kvantum
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt5/6 Settings and Kvantum theme engines" "yes" "yes"

# Prepare assets directory (create if missing)
USER_ASSETS_DIR="/home/$SUDO_USER/.config/assets"
mkdir -p "$USER_ASSETS_DIR"

# Copy assets folder from your repo to user's .config/assets
# Assuming your repo structure: hypr/assets
ASSETS_SRC="$SCRIPT_DIR/../hypr/assets"

if [ -d "$ASSETS_SRC" ]; then
    run_command "cp -r $ASSETS_SRC/* $USER_ASSETS_DIR/" "Copy assets to persistent location" "no" "no"
else
    print_warning "Assets folder not found at $ASSETS_SRC. Skipping asset copy."
    log_message "Assets folder missing, skipped copying assets."
fi

# Extract Catppuccin GTK theme if archive exists
THEME_ARCHIVE="$USER_ASSETS_DIR/themes/Catppuccin-Mocha.tar.xz"
if [ -f "$THEME_ARCHIVE" ]; then
    run_command "sudo tar -xvf $THEME_ARCHIVE -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "no" "yes"
else
    print_warning "Catppuccin GTK theme archive not found at $THEME_ARCHIVE. Skipping extraction."
fi

# Extract Tela Circle Dracula icon theme if archive exists
ICON_ARCHIVE="$USER_ASSETS_DIR/icons/Tela-circle-dracula.tar.xz"
if [ -f "$ICON_ARCHIVE" ]; then
    run_command "sudo tar -xvf $ICON_ARCHIVE -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "no" "yes"
else
    print_warning "Tela Circle Dracula icon archive not found at $ICON_ARCHIVE. Skipping extraction."
fi

# Install Kvantum Catppuccin theme from AUR using yay
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin theme for Kvantum" "yes" "no"

# Copy Kitty config for Catppuccin theme
KITTY_CONFIG_SRC="$SCRIPT_DIR/../simple-hyprland/configs/kitty"
KITTY_CONFIG_DEST="/home/$SUDO_USER/.config/kitty"
if [ -d "$KITTY_CONFIG_SRC" ]; then
    mkdir -p "$KITTY_CONFIG_DEST"
    run_command "cp -r $KITTY_CONFIG_SRC/* $KITTY_CONFIG_DEST/" "Copy Catppuccin Kitty theme config" "no" "no"
else
    print_warning "Kitty config folder not found at $KITTY_CONFIG_SRC. Skipping Kitty config copy."
fi

# Post-install instructions
print_info "\nPost-installation instructions:"
print_bold_blue "Set themes and icons:"
echo "   - Run 'nwg-look' and set the global GTK and icon theme to Catppuccin."
echo "   - Open 'kvantummanager' (run as your user) to select and apply the Catppuccin Kvantum theme."
echo "   - Open 'qt6ct' to set the icon theme and configure Qt6 apps."
echo "   - Restart your session or reboot to apply all theme changes."

echo "------------------------------------------------------------------------"
