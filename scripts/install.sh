#!/bin/bash
# ==========================
# Full Automatic Hyprland Installer with Pywal16
# ==========================

set -euo pipefail

# --------------------------
# Helper functions
# --------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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
# Helper functions
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
  sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
  thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
  gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb yazi
  polkit polkit-gnome
  waybar cliphist papirus-icon-theme
  starship fastfetch swww hyprpicker hyprlock hypridle
  firefox
)

print_bold_blue "Installing official repo packages..."
pacman -S --noconfirm "${PACMAN_PACKAGES[@]}"

# Enable services
systemctl enable --now polkit.service
systemctl enable sddm.service

# --------------------------
# AUR packages
# --------------------------
AUR_PACKAGES=(tofi grimblast pywal16)
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
# Pywal setup
# --------------------------
WALLPAPERS_DEST="$CONFIG_DIR/assets/wallpapers"
mkdir -p "$WALLPAPERS_DEST"
copy_as_user "$ASSETS_SRC/wallpapers" "$WALLPAPERS_DEST"

PYWAL_SCRIPT="$CONFIG_DIR/pywal-apply.sh"
mkdir -p "$(dirname "$PYWAL_SCRIPT")"
cat > "$PYWAL_SCRIPT" << 'EOF'
#!/bin/bash
WALL_DIR="$HOME/.config/assets/wallpapers"
WALL=$(find "$WALL_DIR" -type f | shuf -n1)
wal -i "$WALL"
EOF
chmod +x "$PYWAL_SCRIPT"
chown "$USER_NAME:$USER_NAME" "$PYWAL_SCRIPT"

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

print_success "✅ Full Hyprland + Pywal16 setup complete! Reboot recommended."
