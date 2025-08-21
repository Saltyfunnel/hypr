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
print_success "✅ Pacman packages installed."

# --- yay ---
print_header "Installing yay"
YAY_DIR="$USER_HOME/yay"
if ! command -v yay &>/dev/null; then
    if [ ! -d "$YAY_DIR" ]; then
        sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    fi
    cd "$YAY_DIR"
    sudo -u "$USER_NAME" makepkg -si --noconfirm
fi

# --- AUR: tofi ---
print_header "Installing tofi (AUR)"
if ! command -v tofi &>/dev/null; then
    sudo -u "$USER_NAME" yay -S --noconfirm tofi
fi
print_success "✅ Tofi installed."

# --- Copy configs ---
print_header "Copying configs"
for dir in hypr waybar kitty dunst tofi fastfetch starship; do
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/$dir"
    sudo -u "$USER_NAME" cp -r "$SCRIPT_DIR/configs/$dir/." "$CONFIG_DIR/$dir/" || true
done

# --- Make Waybar scripts executable ---
SCRIPTS_DIR="$CONFIG_DIR/waybar/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    print_header "Setting executable permissions for Waybar scripts"
    sudo -u "$USER_NAME" find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;
    print_success "✅ Waybar scripts are now executable."
else
    print_warning "Waybar scripts folder not found at $SCRIPTS_DIR"
fi

# --- Assets ---
ASSETS_SRC="$SCRIPT_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"
sudo -u "$USER_NAME" mkdir -p "$ASSETS_DEST"
sudo -u "$USER_NAME" cp -r "$ASSETS_SRC/." "$ASSETS_DEST/"

# --- Pywal ---
print_header "Applying pywal theme"
WALLPAPER="$ASSETS_DEST/wallpaper.jpg"
if [ -f "$WALLPAPER" ]; then
    sudo -u "$USER_NAME" env HOME="$USER_HOME" wal -i "$WALLPAPER" -n || true
    print_success "✅ Pywal colors generated."
else
    print_error "No wallpaper found at $WALLPAPER"
fi

PYWAL_COLORS="$USER_HOME/.cache/wal/colors.sh"

# --- Apply Pywal to Starship ---
STARSHIP_CONFIG="$CONFIG_DIR/starship/starship.toml"
if [ -f "$PYWAL_COLORS" ] && [ -f "$STARSHIP_CONFIG" ]; then
sudo -u "$USER_NAME" env HOME="$USER_HOME" bash <<'EOSU'
set -e
COLORS="$HOME/.cache/wal/colors.sh"
STAR="$HOME/.config/starship/starship.toml"
if [[ -f "$COLORS" && -f "$STAR" ]]; then
    . "$COLORS"
    background="${background:-#282a36}"
    foreground="${foreground:-#f8f8f2}"
    color1="${color1:-#ff79c6}"
    color2="${color2:-#50fa7b}"
    color3="${color3:-#ffb86c}"
    color4="${color4:-#6272a4}"
    color5="${color5:-#bd93f9}"

    sed -i -E \
      -e "s/bg:#44475a/bg:${background}/g" \
      -e "s/fg:#f8f8f2/fg:${foreground}/g" \
      -e "s/bg:#6272a4/bg:${color4}/g" \
      -e "s/bg:#50fa7b/bg:${color2}/g" \
      -e "s/bg:#bd93f9/bg:${color5}/g" \
      -e "s/bg:#ff79c6/bg:${color1}/g" \
      -e "s/bg:#ffb86c/bg:${color3}/g" \
      "$STAR"
fi
EOSU
    print_success "✅ Starship colors updated with Pywal."
fi

# --- Apply Pywal to Tofi ---
TOFI_CONFIG="$CONFIG_DIR/tofi/config"
if [ -f "$PYWAL_COLORS" ] && [ -f "$TOFI_CONFIG" ]; then
sudo -u "$USER_NAME" env HOME="$USER_HOME" bash <<'EOSU'
set -e
COLORS="$HOME/.cache/wal/colors.sh"
TOFI="$HOME/.config/tofi/config"
if [[ -f "$COLORS" && -f "$TOFI" ]]; then
    . "$COLORS"
    background="${background:-#282a36}"
    foreground="${foreground:-#f8f8f2}"
    color3="${color3:-#ffb86c}"

    grep -q '^text-color' "$TOFI" || printf '\ntext-color = %s\n' "$foreground" >> "$TOFI"
    grep -q '^background-color' "$TOFI" || printf 'background-color = %s\n' "${background}cc" >> "$TOFI"
    grep -q '^selection-color' "$TOFI" || printf 'selection-color = %s\n' "$color3" >> "$TOFI"
    grep -q '^selection-text-color' "$TOFI" || printf 'selection-text-color = %s\n' "$foreground" >> "$TOFI"

    sed -i -E \
      -e "s|^text-color *=.*|text-color = ${foreground}|" \
      -e "s|^background-color *=.*|background-color = ${background}cc|" \
      -e "s|^selection-color *=.*|selection-color = ${color3}|" \
      -e "s|^selection-text-color *=.*|selection-text-color = ${foreground}|" \
      "$TOFI"
fi
EOSU
    print_success "✅ Tofi colors updated with Pywal."
fi

# --- Fastfetch ---
print_header "Setting up fastfetch"
FASTFETCH_SRC="$SCRIPT_DIR/configs/fastfetch"
FASTFETCH_DEST="$CONFIG_DIR/fastfetch"
if [ -d "$FASTFETCH_SRC" ]; then
    sudo -u "$USER_NAME" mkdir -p "$FASTFETCH_DEST"
    sudo -u "$USER_NAME" cp -r "$FASTFETCH_SRC/." "$FASTFETCH_DEST/"
    print_success "✅ Fastfetch config copied."
else
    print_warning "No fastfetch config found in $FASTFETCH_SRC"
fi

# --- Symlink GTK css ---
GTK_DIR="$USER_HOME/.config/gtk-3.0"
sudo -u "$USER_NAME" mkdir -p "$GTK_DIR"
sudo -u "$USER_NAME" ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk.css"
sudo -u "$USER_NAME" ln -sf "$USER_HOME/.cache/wal/colors-gtk.css" "$GTK_DIR/gtk-dark.css"

# --- SDDM theme only ---
print_header "Setting SDDM theme"
cp -r "$ASSETS_SRC/sddm/corners" /usr/share/sddm/themes/ || true
echo -e "[Theme]\nCurrent=corners" > /etc/sddm.conf

# --- Auto-run Pywal on login ---
print_header "Configuring Pywal autostart"
BASHRC="$USER_HOME/.bashrc"
if ! grep -q "wal -R" "$BASHRC"; then
    echo "wal -R" >> "$BASHRC"
fi
print_success "✅ Pywal will auto-restore colors on login."

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
