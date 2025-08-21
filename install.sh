#!/bin/bash
# Hyprland + Pywal themed setup for Arch
set -euo pipefail

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

# --- Packages ---
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

# --- yay ---
print_header "Installing yay"
YAY_DIR="$USER_HOME/yay"
if [ ! -d "$YAY_DIR" ]; then
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    cd "$YAY_DIR"
    sudo -u "$USER_NAME" makepkg -si --noconfirm
fi

# --- AUR packages ---
print_header "Installing AUR packages"
AUR_APPS=(tofi)
for app in "${AUR_APPS[@]}"; do
    sudo -u "$USER_NAME" yay -S --noconfirm "$app"
done

# --- Copy configs ---
print_header "Copying configs"
for dir in hypr waybar kitty dunst tofi fastfetch starship scripts; do
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/$dir"
    sudo -u "$USER_NAME" cp -r "$SCRIPT_DIR/configs/$dir/." "$CONFIG_DIR/$dir/"
done

# --- Make Waybar scripts executable ---
SCRIPTS_DIR="$CONFIG_DIR/waybar/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    print_header "Setting executable permissions for Waybar scripts"
    sudo -u "$USER_NAME" find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    print_success "✅ Waybar scripts are now executable."
fi

# --- Assets ---
ASSETS_SRC="$SCRIPT_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"
sudo -u "$USER_NAME" mkdir -p "$ASSETS_DEST"
sudo -u "$USER_NAME" cp -r "$ASSETS_SRC/." "$ASSETS_DEST/"

# --- Pywal ---
print_header "Applying Pywal theme"
WALLPAPER="$ASSETS_DEST/wallpaper.jpg"
if [ -f "$WALLPAPER" ]; then
    sudo -u "$USER_NAME" wal -i "$WALLPAPER" -n
    print_success "✅ Pywal colors generated."
else
    print_error "No wallpaper found at $WALLPAPER"
fi

PYWAL_COLORS="$USER_HOME/.cache/wal/colors.sh"

# --- Apply Pywal to Starship ---
STARSHIP_CONFIG="$CONFIG_DIR/starship/starship.toml"
if [ -f "$PYWAL_COLORS" ] && [ -f "$STARSHIP_CONFIG" ]; then
    sudo -u "$USER_NAME" bash -c "source $PYWAL_COLORS && \
        sed -i 's/bg:#44475a/bg:$background/g' $STARSHIP_CONFIG && \
        sed -i 's/fg:#f8f8f2/fg:$foreground/g' $STARSHIP_CONFIG && \
        sed -i 's/bg:#6272a4/bg:$color4/g' $STARSHIP_CONFIG && \
        sed -i 's/bg:#50fa7b/bg:$color2/g' $STARSHIP_CONFIG && \
        sed -i 's/bg:#bd93f9/bg:$color5/g' $STARSHIP_CONFIG && \
        sed -i 's/bg:#ff79c6/bg:$color1/g' $STARSHIP_CONFIG && \
        sed -i 's/bg:#ffb86c/bg:$color3/g' $STARSHIP_CONFIG"
    print_success "✅ Starship colors updated with Pywal."
fi

# --- Apply Pywal to Tofi ---
TOFI_CONFIG="$CONFIG_DIR/tofi/config"
if [ -f "$TOFI_CONFIG" ] && [ -f "$PYWAL_COLORS" ]; then
    sudo -u "$USER_NAME" bash -c "source $PYWAL_COLORS && \
        sed -i 's/^text-color=.*/text-color=\"$foreground\"/' $TOFI_CONFIG && \
        sed -i 's/^background-color=.*/background-color=\"${background}cc\"/' $TOFI_CONFIG && \
        sed -i 's/^selection-color=.*/selection-color=\"$color3\"/' $TOFI_CONFIG && \
        sed -i 's/^selection-text-color=.*/selection-text-color=\"$foreground\"/' $TOFI_CONFIG"
    print_success "✅ Tofi colors updated with Pywal."
fi

# --- Generate fastfetch config ---
print_header "Generating fastfetch config"
FASTFETCH_SCRIPT="$CONFIG_DIR/scripts/generate_fastfetch.sh"
if [ -f "$FASTFETCH_SCRIPT" ]; then
    sudo -u "$USER_NAME" bash "$FASTFETCH_SCRIPT"
    print_success "✅ Fastfetch config generated"
fi

# --- Generate Hyprland Pywal colors ---
print_header "Generating Hyprland Pywal colors"
HYPR_COLORS_SCRIPT="$CONFIG_DIR/scripts/generate_hypr_colors.sh"
if [ -f "$HYPR_COLORS_SCRIPT" ]; then
    sudo -u "$USER_NAME" bash "$HYPR_COLORS_SCRIPT"
    print_success "✅ Hyprland colors generated"
fi

# --- Symlink GTK css ---
GTK_DIR="$USER_HOME/.config/gtk-3.0"
sudo -u "$USER_NAME" mkdir -p "$GTK_DIR"
sudo -u "$USER_NAME" ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk.css"
sudo -u "$USER_NAME" ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk-dark.css"

# --- SDDM ---
print_header "Setting SDDM theme"
cp -r "$ASSETS_SRC/sddm/corners" /usr/share/sddm/themes/
echo -e "[Theme]\nCurrent=corners" > /etc/sddm.conf

# --- GPU Drivers ---
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
print_success "✅ GPU driver installation complete."

# --- Enable services ---
systemctl enable --now sddm.service
systemctl enable --now polkit.service
print_success "✅ Services enabled"

print_success "\n🎉 Install complete! Reboot into Hyprland."
