#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

# Define base directories
CONFIGS_DIR="/home/$SUDO_USER/simple-hyprland/configs"
TARGET_CONFIG_DIR="/home/$SUDO_USER/.config"

log_message "Installation started for hypr section"
print_info "\nStarting Hyprland setup..."

print_info "\nEverything below is recommended to INSTALL"

# Install Hyprland
run_command "pacman -S --noconfirm hyprland" "Install Hyprland (Must)" "yes"

# Copy Hyprland config
HYPRLAND_CONF_SRC="$CONFIGS_DIR/hypr/hyprland.conf"
HYPRLAND_CONF_DST="$TARGET_CONFIG_DIR/hypr"

if [ -f "$HYPRLAND_CONF_SRC" ]; then
    run_command "mkdir -p $HYPRLAND_CONF_DST && cp $HYPRLAND_CONF_SRC $HYPRLAND_CONF_DST/" "Copy Hyprland config (Must)" "yes" "no"
else
    print_warning "⚠️ Hyprland config not found at $HYPRLAND_CONF_SRC. Skipping copy."
    log_message "Hyprland config missing. Skipped copy."
fi

# Install XDG Desktop Portal for Hyprland
run_command "pacman -S --noconfirm xdg-desktop-portal-hyprland" "Install XDG Desktop Portal for Hyprland" "yes"

# Install Polkit authentication agent
run_command "pacman -S --noconfirm polkit-kde-agent" "Install KDE Polkit Agent" "yes"

# Install Dunst notification daemon
run_command "pacman -S --noconfirm dunst" "Install Dunst notification daemon" "yes"

# Copy Dunst config
DUNST_SRC="$CONFIGS_DIR/dunst"
DUNST_DST="$TARGET_CONFIG_DIR/dunst"

if [ -d "$DUNST_SRC" ]; then
    run_command "mkdir -p $DUNST_DST && cp -r $DUNST_SRC/* $DUNST_DST/" "Copy Dunst config" "yes" "no"
else
    print_warning "⚠️ Dunst config not found at $DUNST_SRC. Skipping copy."
    log_message "Dunst config missing. Skipped copy."
fi

# QT Wayland support
run_command "pacman -S --noconfirm qt5-wayland qt6-wayland" "Install Qt5 & Qt6 Wayland Support" "yes"

echo "------------------------------------------------------------------------"
