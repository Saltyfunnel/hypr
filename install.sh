#!/bin/bash
# Hyprland + Pywal themed setup for Arch Linux
set -euo pipefail

# --- Helper Functions ---
print_header()  { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success() { echo -e "\e[32m$1\e[0m"; }
print_warning() { echo -e "\e[33mWarning: $1\e[0m"; }
print_error()   { echo -e "\e[31mError: $1\e[0m"; exit 1; }

if [ "$EUID" -ne 0 ]; then
    print_error "Run as root (sudo bash $0)."
fi

# --- User Info ---
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
USER_UID="$(id -u "$USER_NAME")"
CONFIG_DIR="$USER_HOME/.config"

# --- Ensure XDG_RUNTIME_DIR exists ---
RUNTIME_DIR="/run/user/$USER_UID"
if [ ! -d "$RUNTIME_DIR" ]; then
    mkdir -p "$RUNTIME_DIR"
    chown "$USER_NAME":"$USER_NAME" "$RUNTIME_DIR"
    chmod 700 "$RUNTIME_DIR"
fi
export XDG_RUNTIME_DIR="$RUNTIME_DIR"

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
print_success "✅ System packages installed."

# --- yay (AUR helper) ---
print_header "Installing yay"
YAY_DIR="$USER_HOME/yay"
if [ ! -d "$YAY_DIR" ]; then
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    cd "$YAY_DIR"
    sudo -u "$USER_NAME" makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
fi
print_success "✅ yay installed."

# --- AUR Apps ---
print_header "Installing AUR apps"
AUR_APPS=( tofi )
for app in "${AUR_APPS[@]}"; do
    sudo -u "$USER_NAME" yay -S --noconfirm "$app"
done
print_success "✅ AUR apps installed."

# --- Copy configs ---
print_header "Copying configuration files"
CONFIG_FOLDERS=( hypr waybar kitty dunst tofi fastfetch starship )
for dir in "${CONFIG_FOLDERS[@]}"; do
    mkdir -p "$CONFIG_DIR/$dir"
    cp -r "$SCRIPT_DIR/configs/$dir/." "$CONFIG_DIR/$dir/"
done

# --- Make Waybar scripts executable ---
SCRIPTS_DIR="$CONFIG_DIR/waybar/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    print_header "Setting Waybar scripts executable"
    find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
fi

# --- Assets ---
ASSETS_SRC="$SCRIPT_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"
mkdir -p "$ASSETS_DEST"
cp -r "$ASSETS_SRC/." "$ASSETS_DEST/"

# --- Pywal ---
print_header "Applying Pywal theme"
WALLPAPER="$ASSETS_DEST/wallpaper.jpg"
if [ ! -f "$WALLPAPER" ]; then
    print_error "No wallpaper found at $WALLPAPER"
fi
sudo -u "$USER_NAME" wal -i "$WALLPAPER" -n
print_success "✅ Pywal generated colors"

PYWAL_COLORS="$USER_HOME/.cache/wal/colors.sh"

# --- Starship theming ---
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
fi

# --- Tofi theming ---
TOFI_CONFIG="$CONFIG_DIR/tofi/config"
if [ -f "$TOFI_CONFIG" ]; then
    sudo -u "$USER_NAME" bash -c "source $PYWAL_COLORS && \
        sed -i 's/^text-color=.*/text-color=\"$foreground\"/' $TOFI_CONFIG && \
        sed -i 's/^background-color=.*/background-color=\"${background}cc\"/' $TOFI_CONFIG && \
        sed -i 's/^selection-color=.*/selection-color=\"$color3\"/' $TOFI_CONFIG && \
        sed -i 's/^selection-text-color=.*/selection-text-color=\"$foreground\"/' $TOFI_CONFIG"
fi

# --- Generate fastfetch ---
FASTFETCH_SCRIPT="$CONFIG_DIR/scripts/generate_fastfetch.sh"
if [ -f "$FASTFETCH_SCRIPT" ]; then
    sudo -u "$USER_NAME" bash "$FASTFETCH_SCRIPT"
fi

# --- GTK ---
GTK_DIR="$CONFIG_DIR/gtk-3.0"
mkdir -p "$GTK_DIR"
ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk.css"
ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk-dark.css"

# --- SDDM ---
print_header "Configuring SDDM theme"
cp -r "$ASSETS_SRC/sddm/corners" /usr/share/sddm/themes/
echo -e "[Theme]\nCurrent=corners" > /etc/sddm.conf

# --- GPU Drivers ---
print_header "Installing GPU drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi nvidia; then
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi amd; then
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
elif echo "$GPU_INFO" | grep -qi intel; then
    pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel
else
    print_warning "No supported GPU detected"
fi

# --- Enable services ---
systemctl enable --now sddm.service
systemctl enable --now polkit.service

print_success "\n🎉 Install complete! Reboot and log in as $USER_NAME into Hyprland."
