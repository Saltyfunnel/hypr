#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

log_message "Installation started for utilities section"
print_info "\nStarting utilities setup..."

# Ensure yay is installed
if ! command -v yay &> /dev/null; then
    print_error "YAY is not installed. Please ensure prerequisites.sh installs yay successfully."
    exit 1
fi

### Waybar
run_command "pacman -S --noconfirm waybar" "Install Waybar - Status Bar" "yes"
run_command "cp -r /home/$SUDO_USER/hypr/configs/waybar /home/$SUDO_USER/.config/" "Copy Waybar config" "yes" "no"

### Tofi
run_command "yay -S --sudoloop --noconfirm tofi" "Install Tofi - Application Launcher" "yes" "no"
run_command "cp -r /home/$SUDO_USER/hypr/configs/tofi /home/$SUDO_USER/.config/" "Copy Tofi config(s)" "yes" "no"

### Cliphist
run_command "pacman -S --noconfirm cliphist" "Install Cliphist - Clipboard Manager" "yes"

### SWWW
run_command "yay -S --sudoloop --noconfirm swww" "Install SWWW for wallpaper management" "yes" "no"

# Ensure backgrounds folder exists before copy
run_command "mkdir -p /home/$SUDO_USER/.config/assets/backgrounds" "Create backgrounds directory" "no" "no"
run_command "cp -r /home/$SUDO_USER/hypr/assets/backgrounds/* /home/$SUDO_USER/.config/assets/backgrounds/" "Copy background images" "yes" "no"

### Hyprpicker
run_command "yay -S --sudoloop --noconfirm hyprpicker" "Install Hyprpicker - Color Picker" "yes" "no"

### Hyprlock
run_command "yay -S --sudoloop --noconfirm hyprlock" "Install Hyprlock - Screen Locker (Must)" "yes" "no"
run_command "mkdir -p /home/$SUDO_USER/.config/hypr" "Ensure Hypr config dir exists" "no" "no"
run_command "cp -r /home/$SUDO_USER/hypr/configs/hypr/hyprlock.conf /home/$SUDO_USER/.config/hypr/" "Copy Hyprlock config" "yes" "no"

### Grimblast
run_command "yay -S --sudoloop --noconfirm grimblast" "Install Grimblast - Screenshot tool" "yes" "no"

### Hypridle
run_command "yay -S --sudoloop --noconfirm hypridle" "Install Hypridle for idle management (Must)" "yes" "no"
run_command "cp -r /home/$SUDO_USER/hypr/configs/hypr/hypridle.conf /home/$SUDO_USER/.config/hypr/" "Copy Hypridle config" "yes" "no"

echo "------------------------------------------------------------------------"
