#!/bin/bash
# ==========================
# Full Automatic Hyprland Installer (Grim + Slurp, no Pywal config)
# ==========================

set -euo pipefail

# --------------------------
# Helper functions
# --------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_success() { echo -e "${GREEN}$1${NC}"; }
print_info()    { echo -e "${BLUE}$1${NC}"; }
print_bold_blue() { echo -e "${BLUE}${BOLD}$1${NC}"; }

# --------------------------
# Check root
# --------------------------
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root."
    exit 1
fi

# --------------------------
# Detect user
# --------------------------
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hypr"
ASSETS_SRC="$REPO_DIR/assets"
CONFIG_SRC="$REPO_DIR/configs"

# --------------------------
# Helper function to copy files
# --------------------------
copy_as_user() {
    local src="$1"
    local dest="$2"
    if [ -d "$src" ]; then
        mkdir -p "$dest"
        cp -r "$src"/* "$dest"
        chown -R "$USER_NAME:$USER_NAME" "$dest"
    else
        echo "Warning: source $src does not exist"
    fi
}

# --------------------------
# Update system
# --------------------------
print_bold_blue "Updating system packages..."
pacman -Syyu --noconfirm

# --------------------------
# Install yay if missing
# --------------------------
if ! command -v yay &>/dev/null; then
    print_info "Installing yay..."
    pacman -S --noconfirm --needed git base-devel
    mkdir -p /tmp
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    chown -R "$USER_NAME:$USER_NAME" /tmp/yay
    cd /tmp/yay
    sudo -u "$USER_NAME" makepkg -si --noconfirm
    rm -rf /tmp/yay
fi

# --------------------------
# Pacman packages
# --------------------------
PACMAN_PACKAGES=(
  pipewire wireplumber pamixer brightnessctl
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
  ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
  sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo python-pywal
  thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
  gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb
  polkit polkit-gnome
  waybar cliphist papirus-icon-theme
  starship fastfetch swww hyprpicker hyprlock hypridle hyprland
  firefox yazi
  grim slurp wl-clipboard jq
)

print_bold_blue "Installing official repo packages..."
pacman -S --noconfirm "${PACMAN_PACKAGES[@]}"

# Enable services
systemctl enable --now polkit.service
systemctl enable sddm.service

# --------------------------
# AUR packages
# --------------------------
AUR_PACKAGES=(tofi)
print_bold_blue "Installing AUR packages..."
for pkg in "${AUR_PACKAGES[@]}"; do
    sudo -u "$USER_NAME" yay -S --sudoloop --noconfirm "$pkg"
done

# --------------------------
# Copy configs
# --------------------------
print_bold_blue "Copying configuration files..."
copy_as_user "$CONFIG_SRC/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$CONFIG_SRC/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$CONFIG_SRC/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$CONFIG_SRC/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$CONFIG_SRC/dunst" "$CONFIG_DIR/dunst"

STARSHIP_SRC="$CONFIG_SRC/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
if [ -f "$STARSHIP_SRC" ]; then
    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
    chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
fi

# --------------------------
# Copy wallpapers
# --------------------------
print_bold_blue "Copying wallpapers..."
WALLPAPERS_DEST="$CONFIG_DIR/assets/wallpapers"
mkdir -p "$WALLPAPERS_DEST"
copy_as_user "$ASSETS_SRC/wallpapers" "$WALLPAPERS_DEST"

# --------------------------
# SDDM Theme setup (fixed clone)
# --------------------------
MONO_SDDM_REPO="https://github.com/pwyde/monochrome-kde.git"
MONO_SDDM_TEMP="/tmp/monochrome-kde"
MONO_THEME_NAME="monochrome"

mkdir -p /tmp
rm -rf "$MONO_SDDM_TEMP"
git clone --depth=1 "$MONO_SDDM_REPO" "$MONO_SDDM_TEMP"

cp -r "$MONO_SDDM_TEMP/sddm/themes/$MONO_THEME_NAME" "/usr/share/sddm/themes/$MONO_THEME_NAME"
chown -R root:root "/usr/share/sddm/themes/$MONO_THEME_NAME"

mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=$MONO_THEME_NAME" > /etc/sddm.conf.d/10-theme.conf

rm -rf "$MONO_SDDM_TEMP"

# --------------------------
# GPU detection and drivers
# --------------------------
print_bold_blue "Detecting GPU..."
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi "amd"; then
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
elif echo "$GPU_INFO" | grep -qi "intel"; then
    pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel
else
    echo "Warning: No supported GPU detected."
fi

print_success "✅ Full Hyprland setup complete! Reboot recommended."
