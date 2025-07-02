#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helper.sh" # Source helper after SCRIPT_DIR is set

log_message "Installation started for theming section"
print_info "\n🎨 Starting theming setup..."

USER_HOME="/home/$SUDO_USER"
# Define consistent paths relative to script location
CONFIGS_DIR="$SCRIPT_DIR/../configs"
ASSETS_DIR="$SCRIPT_DIR/../assets"

THEME_NAME="Catppuccin-Mocha"
ICON_NAME="Tela-circle-dracula"

# 1. Install GTK theming tools and engines
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes"
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt5/6 Settings and Kvantum engine" "yes"

# 2. Extract themes and icons
if [ -f "$ASSETS_DIR/themes/${THEME_NAME}.tar.xz" ]; then
    run_command "tar -xvf \"$ASSETS_DIR/themes/${THEME_NAME}.tar.xz\" -C /usr/share/themes/" "Install $THEME_NAME GTK theme" "yes"
else
    print_warning "⚠️ GTK theme archive not found: $ASSETS_DIR/themes/${THEME_NAME}.tar.xz"
    log_message "GTK theme archive not found: $ASSETS_DIR/themes/${THEME_NAME}.tar.xz"
fi

if [ -f "$ASSETS_DIR/icons/${ICON_NAME}.tar.xz" ]; then
    run_command "tar -xvf \"$ASSETS_DIR/icons/${ICON_NAME}.tar.xz\" -C /usr/share/icons/" "Install $ICON_NAME icon theme" "yes"
else
    print_warning "⚠️ Icon theme archive not found: $ASSETS_DIR/icons/${ICON_NAME}.tar.xz"
    log_message "Icon theme archive not found: $ASSETS_DIR/icons/${ICON_NAME}.tar.xz"
fi

# 3. Kvantum theme (Catppuccin)
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin Kvantum theme" "yes" "no"

# 4. Copy Kitty config (optional terminal theme)
if [ -d "$CONFIGS_DIR/kitty" ]; then
    run_command "cp -r \"$CONFIGS_DIR/kitty\" \"$USER_HOME/.config/\"" "Copy Kitty config" "yes" "no" # Use run_command
    # chown is already handled by run_command (due to 'no' for use_sudo)
    print_success "✅ Kitty config copied."
else
    print_warning "⚠️ Kitty config directory not found: $CONFIGS_DIR/kitty"
    log_message "Kitty config directory not found: $CONFIGS_DIR/kitty"
fi

# 5. Post-install instructions for user
print_info "\n🧩 Post-installation instructions:"
print_bold_blue "🔧 Set themes and icons:"
echo "   - Run 'nwg-look' as $SUDO_USER to apply GTK theme and icons."
echo "   - Run 'kvantummanager' and select 'Catppuccin' as the active Qt theme."
echo "   - Run 'qt6ct' and set icon and font settings there."

# 6. Optional: Force GTK apps like Nautilus to follow the theme (for the user)
GTK_THEME_SETTINGS="
[Settings]
gtk-theme-name=$THEME_NAME
gtk-icon-theme-name=$ICON_NAME
gtk-font-name=Sans 10
"
run_command "mkdir -p \"$USER_HOME/.config/gtk-3.0\"" "Create gtk-3.0 config dir" "no" "no"
run_command "mkdir -p \"$USER_HOME/.config/gtk-4.0\"" "Create gtk-4.0 config dir" "no" "no"
# Use sudo -u for echo to ensure file creation is under SUDO_USER's ownership
sudo -u "$SUDO_USER" echo "$GTK_THEME_SETTINGS" > "$USER_HOME/.config/gtk-3.0/settings.ini"
sudo -u "$SUDO_USER" echo "$GTK_THEME_SETTINGS" > "$USER_HOME/.config/gtk-4.0/settings.ini"
# chown -R is no longer needed if files are created directly by sudo -u SUDO_USER
# chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config/gtk-"*

print_success "\n🎉 Theming setup complete!"
echo "------------------------------------------------------------------------"
log_message "Theming setup completed."
