#!/bin/bash

# Get current script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helper.sh"

log_message "Installation started for utilities section"
print_info "\nStarting utilities setup..."

# Define consistent paths
USER_HOME="/home/$SUDO_USER"
CONFIGS_DIR="$SCRIPT_DIR/../configs"
ASSETS_DIR="$SCRIPT_DIR/../assets"

# Check for yay
if ! command -v yay &> /dev/null; then
    print_error "YAY is not installed. Please ensure prerequisites.sh installs yay successfully."
    exit 1
fi

### Waybar
run_command "pacman -S --noconfirm waybar" "Install Waybar - Status Bar" "yes"
run_command "cp -r $CONFIGS_DIR/waybar $USER_HOME/.config/" "Copy Waybar config" "yes" "no"

### Tofi
run_command "yay -S --sudoloop --noconfirm tofi" "Install Tofi - Application Launcher" "yes" "no"
run_command "cp -r $CONFIGS_DIR/tofi $USER_HOME/.config/" "Copy Tofi config(s)" "yes" "no"

### Cliphist
run_command "pacman -S --noconfirm cliphist" "Install Cliphist - Clipboard Manager" "yes"

### SWWW
run_command "yay -S --sudoloop --noconfirm swww" "Install SWWW for wallpaper management" "yes" "no"
run_command "mkdir -p $USER_HOME/.config/assets/backgrounds" "Create backgrounds directory" "no" "no"
run_command "cp -r $ASSETS_DIR/backgrounds/* $USER_HOME/.config/assets/backgrounds/" "Copy background images" "yes" "no"

### Hyprpicker
run_command "yay -S --sudoloop --noconfirm hyprpicker" "Install Hyprpicker - Color Picker" "yes" "no"

### Hyprlock
run_command "yay -S --sudoloop --noconfirm hyprlock" "Install Hyprlock - Screen Locker (Must)" "yes" "no"
run_command "mkdir -p $USER_HOME/.config/hypr" "Ensure Hypr config dir exists" "no" "no"
run_command "cp -r $CONFIGS_DIR/hypr/hyprlock.conf $USER_HOME/.config/hypr/" "Copy Hyprlock config" "yes" "no"

### Wlogout
run_command "yay -S --sudoloop --noconfirm wlogout" "Install Wlogout - Session Manager" "yes" "no"
run_command "cp -r $CONFIGS_DIR/wlogout $USER_HOME/.config/" "Copy Wlogout config" "yes" "no"
run_command "mkdir -p $USER_HOME/.config/assets/wlogout" "Create wlogout assets dir" "no" "no"
run_command "cp -r $ASSETS_DIR/wlogout/* $USER_HOME/.config/assets/wlogout/" "Copy Wlogout assets" "yes" "no"

### Grimblast
run_command "yay -S --sudoloop --noconfirm grimblast" "Install Grimblast - Screenshot tool" "yes" "no"

### Hypridle
run_command "yay -S --sudoloop --noconfirm hypridle" "Install Hypridle for idle management (Must)" "yes" "no"
run_command "cp -r $CONFIGS_DIR/hypr/hypridle.conf $USER_HOME/.config/hypr/" "Copy Hypridle config" "yes" "no"

echo "✅ Utilities setup complete."
echo "------------------------------------------------------------------------"
