#!/bin/bash
# Post-install setup for Arch + Hyprland
set -euo pipefail

print_header()   { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success()  { echo -e "\e[32m$1\e[0m"; }
print_warning()  { echo -e "\e[33mWarning: $1\e[0m"; }
print_error()    { echo -e "\e[31mError: $1\e[0m"; exit 1; }

# Require root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (e.g., sudo ./$(basename "$0"))."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"

# --- Packages ---
print_header "Installing official packages"
PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    kitty nano tar unzip firefox mpv dunst cava code
    yazi gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar starship fastfetch python-pywal
)
pacman -S --needed --noconfirm "${PACKAGES[@]}"
print_success "✅ Official packages installed."

# --- AUR packages via yay ---
print_header "Installing AUR packages"
AUR_PACKAGES=( tofi ttf-jetbrains-mono-nerd ttf-iosevka-nerd )
sudo -u "$USER_NAME" yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
print_success "✅ AUR packages installed."

# --- Copy configs ---
print_header "Copying user configs"
for dir in hypr waybar kitty dunst tofi starship autostart; do
    if [ -d "$SCRIPT_DIR/configs/$dir" ]; then
        sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/$dir"
        sudo -u "$USER_NAME" cp -r "$SCRIPT_DIR/configs/$dir/." "$CONFIG_DIR/$dir/"
    else
        print_warning "Config for $dir not found"
    fi
done

# --- Make scripts executable ---
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    print_header "Making scripts executable"
    find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    print_success "✅ All scripts are executable."
else
    print_warning "Scripts folder not found at $SCRIPTS_DIR"
fi

# --- Assets ---
ASSETS_SRC="$SCRIPT_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"
sudo -u "$USER_NAME" mkdir -p "$ASSETS_DEST"
if [ -d "$ASSETS_SRC" ]; then
    sudo -u "$USER_NAME" cp -r "$ASSETS_SRC/." "$ASSETS_DEST/"
fi

# --- Pywal ---
print_header "Applying pywal theme"
WALLPAPER="$ASSETS_DEST/wallpaper.jpg"
if [ -f "$WALLPAPER" ]; then
    sudo -u "$USER_NAME" wal -i "$WALLPAPER" -n
    print_success "✅ Pywal colors generated."
else
    print_warning "No wallpaper found at $WALLPAPER"
fi
PYWAL_COLORS="$USER_HOME/.cache/wal/colors.sh"

# --- Apply Pywal to Starship ---
STARSHIP_CONFIG="$CONFIG_DIR/starship/starship.toml"
if [ -f "$PYWAL_COLORS" ] && [ -f "$STARSHIP_CONFIG" ]; then
    sudo -u "$USER_NAME" bash -c "
        source $PYWAL_COLORS
        sed -i \"s/bg:#44475a/bg:\${background}/\" '$STARSHIP_CONFIG'
        sed -i \"s/fg:#f8f8f2/fg:\${foreground}/\" '$STARSHIP_CONFIG'
        sed -i \"s/bg:#6272a4/bg:\${color4}/\" '$STARSHIP_CONFIG'
        sed -i \"s/bg:#50fa7b/bg:\${color2}/\" '$STARSHIP_CONFIG'
        sed -i \"s/bg:#bd93f9/bg:\${color5}/\" '$STARSHIP_CONFIG'
        sed -i \"s/bg:#ff79c6/bg:\${color1}/\" '$STARSHIP_CONFIG'
        sed -i \"s/bg:#ffb86c/bg:\${color3}/\" '$STARSHIP_CONFIG'
    "
    print_success "✅ Starship colors updated with Pywal."
fi

# --- Apply Pywal to Tofi ---
TOFI_CONFIG="$CONFIG_DIR/tofi/config"
if [ -f "$TOFI_CONFIG" ] && [ -f "$PYWAL_COLORS" ]; then
    sudo -u "$USER_NAME" bash -c "
        source $PYWAL_COLORS
        sed -i \"s/^text-color=.*/text-color=\\\"\${foreground}\\\"/\" '$TOFI_CONFIG'
        sed -i \"s/^background-color=.*/background-color=\\\"\${background}cc\\\"/\" '$TOFI_CONFIG'
        sed -i \"s/^selection-color=.*/selection-color=\\\"\${color3}\\\"/\" '$TOFI_CONFIG'
        sed -i \"s/^selection-text-color=.*/selection-text-color=\\\"\${foreground}\\\"/\" '$TOFI_CONFIG'
    "
    print_success "✅ Tofi colors updated with Pywal."
fi

# --- Symlink GTK css ---
GTK_DIR="$USER_HOME/.config/gtk-3.0"
sudo -u "$USER_NAME" mkdir -p "$GTK_DIR"
sudo -u "$USER_NAME" ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk.css"
sudo -u "$USER_NAME" ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk-dark.css"

print_success "\n🎉 Post-install setup complete! Reboot into Hyprland."
