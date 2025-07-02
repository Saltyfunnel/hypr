#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helper.sh"

# Define consistent relative paths
CONFIGS_DIR="$SCRIPT_DIR/../configs"

print_header "Starting Hyprland setup"

run_command "pacman -S --noconfirm hyprland" "Install Hyprland" "yes"

# Ensure config directory exists before copying
run_command "mkdir -p /home/$SUDO_USER/.config/hypr" "Create hypr config directory" "no" "no"

# Copy hyprland config from the 'hypr' repo folder
run_command "cp -r \"$CONFIGS_DIR/hypr/hyprland.conf\" /home/$SUDO_USER/.config/hypr/" "Copy hyprland config" "yes" "no"

run_command "pacman -S --noconfirm xdg-desktop-portal-hyprland" "Install XDG desktop portal for Hyprland" "yes"
run_command "pacman -S --noconfirm polkit-kde-agent" "Install KDE Polkit agent for authentication dialogs" "yes"
run_command "pacman -S --noconfirm dunst" "Install Dunst notification daemon" "yes"

# Copy dunst config from the 'hypr' repo folder
run_command "cp -r \"$CONFIGS_DIR/dunst\" /home/$SUDO_USER/.config/" "Copy dunst config" "yes" "no"

run_command "pacman -S --noconfirm qt5-wayland qt6-wayland" "Install QT support on Wayland" "yes"

echo "------------------------------------------------------------------------"
