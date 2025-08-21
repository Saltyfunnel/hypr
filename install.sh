#!/bin/bash
# Hyprland + Pywal themed setup for Arch Linux
set -euo pipefail

# -----------------------
# Helper functions
# -----------------------
print_header() { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success() { echo -e "\e[32m$1\e[0m"; }
print_warning() { echo -e "\e[33mWarning: $1\e[0m"; }
print_error() { echo -e "\e[31mError: $1\e[0m"; exit 1; }

if [ "$EUID" -ne 0 ]; then
    print_error "Run as root (sudo bash $0)."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"

# -----------------------
# Install packages
# -----------------------
print_header "Installing packages"
PACKAGES=(
    git base-devel pipewire wireplumber pamixer brightnessctl
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
    sddm kitty nano tar unzip firefox mpv dunst cava code
    yazi gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome
    waybar hyprland hyprpaper hypridle hyprlock starship fastfetch
    python-pywal
)
pacman -Syu --noconfirm "${PACKAGES[@]}"
print_success "✅ Packages installed."

# -----------------------
# Install yay (AUR helper)
# -----------------------
print_header "Installing yay"
YAY_DIR="$USER_HOME/yay"
if [ ! -d "$YAY_DIR" ]; then
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    cd "$YAY_DIR"
    sudo -u "$USER_NAME" makepkg -si --noconfirm
fi

# -----------------------
# Copy configs
# -----------------------
print_header "Copying configs"
for dir in hypr waybar kitty dunst tofi fastfetch starship; do
    SRC="$SCRIPT_DIR/configs/$dir"
    DEST="$CONFIG_DIR/$dir"
    if [ -d "$SRC" ]; then
        sudo -u "$USER_NAME" mkdir -p "$DEST"
        sudo -u "$USER_NAME" cp -r "$SRC/." "$DEST/"
        print_success "✅ Copied $dir"
    else
        print_warning "$SRC not found, skipping."
    fi
done

# -----------------------
# Waybar scripts permissions
# -----------------------
SCRIPTS_DIR="$CONFIG_DIR/waybar/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    print_header "Setting executable permissions for Waybar scripts"
    sudo -u "$USER_NAME" find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    print_success "✅ Waybar scripts are now executable."
fi

# -----------------------
# Assets
# -----------------------
ASSETS_SRC="$SCRIPT_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"
if [ -d "$ASSETS_SRC" ]; then
    sudo -u "$USER_NAME" mkdir -p "$ASSETS_DEST"
    sudo -u "$USER_NAME" cp -r "$ASSETS_SRC/." "$ASSETS_DEST/"
    print_success "✅ Assets copied."
fi

# -----------------------
# Pywal
# -----------------------
print_header "Applying Pywal theme"
WALLPAPER="$ASSETS_DEST/wallpaper.jpg"
PYWAL_COLORS="$USER_HOME/.cache/wal/colors.sh"

if [ -f "$WALLPAPER" ]; then
    sudo -u "$USER_NAME" wal -i "$WALLPAPER" -n
    print_success "✅ Pywal colors generated."
else
    print_warning "No wallpaper found at $WALLPAPER"
fi

# -----------------------
# Starship colors
# -----------------------
STARSHIP_CONFIG="$CONFIG_DIR/starship/starship.toml"
if [ -f "$PYWAL_COLORS" ] && [ -f "$STARSHIP_CONFIG" ]; then
    sudo -u "$USER_NAME" bash -c "
      source $PYWAL_COLORS || true
      : \${background:=#282a36}
      : \${foreground:=#f8f8f2}
      : \${color1:=#ff79c6}
      : \${color2:=#50fa7b}
      : \${color3:=#ffb86c}
      : \${color4:=#6272a4}
      : \${color5:=#bd93f9}

      sed -i 's/bg:#44475a/bg:'\$background'/g' $STARSHIP_CONFIG
      sed -i 's/fg:#f8f8f2/fg:'\$foreground'/g' $STARSHIP_CONFIG
      sed -i 's/bg:#6272a4/bg:'\$color4'/g' $STARSHIP_CONFIG
      sed -i 's/bg:#50fa7b/bg:'\$color2'/g' $STARSHIP_CONFIG
      sed -i 's/bg:#bd93f9/bg:'\$color5'/g' $STARSHIP_CONFIG
      sed -i 's/bg:#ff79c6/bg:'\$color1'/g' $STARSHIP_CONFIG
      sed -i 's/bg:#ffb86c/bg:'\$color3'/g' $STARSHIP_CONFIG
    "
    print_success "✅ Starship colors updated with Pywal."
fi

# -----------------------
# Tofi colors
# -----------------------
TOFI_CONFIG="$CONFIG_DIR/tofi/config"
if [ -f "$TOFI_CONFIG" ] && [ -f "$PYWAL_COLORS" ]; then
    sudo -u "$USER_NAME" bash -c "
      source $PYWAL_COLORS || true
      : \${background:=#282a36}
      : \${foreground:=#f8f8f2}
      : \${color1:=#ff79c6}
      : \${color2:=#50fa7b}
      : \${color3:=#ffb86c}

      sed -i 's/^text-color=.*/text-color=\"'$foreground'\"/' $TOFI_CONFIG
      sed -i 's/^background-color=.*/background-color=\"'${background}cc'\"/' $TOFI_CONFIG
      sed -i 's/^selection-color=.*/selection-color=\"'$color3'\"/' $TOFI_CONFIG
      sed -i 's/^selection-text-color=.*/selection-text-color=\"'$foreground'\"/' $TOFI_CONFIG
    "
    print_success "✅ Tofi colors updated with Pywal."
fi

# -----------------------
# Fastfetch
# -----------------------
FASTFETCH_SCRIPT="$SCRIPT_DIR/configs/scripts/generate_fastfetch.sh"
if [ -f "$FASTFETCH_SCRIPT" ]; then
    print_header "Generating Fastfetch config"
    sudo -u "$USER_NAME" bash "$FASTFETCH_SCRIPT"
    print_success "✅ Fastfetch config generated"
else
    print_warning "Fastfetch generation script not found."
fi

# -----------------------
# GTK symlink
# -----------------------
GTK_DIR="$USER_HOME/.config/gtk-3.0"
sudo -u "$USER_NAME" mkdir -p "$GTK_DIR"
sudo -u "$USER_NAME" ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk.css"
sudo -u "$USER_NAME" ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk-dark.css"

# -----------------------
# SDDM theme
# -----------------------
if [ -d "$ASSETS_SRC/sddm/corners" ]; then
    cp -r "$ASSETS_SRC/sddm/corners" /usr/share/sddm/themes/
    echo -e "[Theme]\nCurrent=corners" > /etc/sddm.conf
    print_success "✅ SDDM theme applied"
else
    print_warning "SDDM theme folder not found"
fi

# -----------------------
# GPU drivers
# -----------------------
print_header "Installing GPU Drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    echo "💻 NVIDIA GPU detected"
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi "amd"; then
    echo "💻 AMD GPU detected"
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
elif echo "$GPU_INFO" | grep -qi "intel"; then
    echo "💻 Intel GPU detected"
    pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel
else
    print_warning "No supported GPU detected"
fi
print_success "✅ GPU drivers installed"

# -----------------------
# Enable services
# -----------------------
systemctl enable --now sddm.service
systemctl enable --now polkit.service
print_success "✅ Services enabled"

print_success "\n🎉 Installation complete! Reboot into Hyprland."
