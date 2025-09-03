#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="/home/${SUDO_USER:-$USER}"
export SUDO_USER  # needed for helper functions

source "$SCRIPT_DIR/helper.sh"

check_root
check_os

print_bold_blue "\n🚀 Starting Full Hyprland Setup"
echo "-------------------------------------"

# -----------------------------------------------------------------------------
# STEP 1: Update system
# -----------------------------------------------------------------------------
print_header "Updating system packages..."
run_command "pacman -Syyu --noconfirm" "System update" "no"

# -----------------------------------------------------------------------------
# STEP 2: Install Yay if missing
# -----------------------------------------------------------------------------
if ! command -v yay &>/dev/null; then
  print_info "Yay not found. Installing yay..."
  run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel for yay" "no"
  run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository" "no"
  run_command "chown -R $SUDO_USER:$SUDO_USER /tmp/yay" "Fix yay directory permissions" "no"
  run_command "cd /tmp/yay && sudo -u $SUDO_USER makepkg -si --noconfirm" "Build and install yay" "no"
  run_command "rm -rf /tmp/yay" "Clean up yay build directory" "no"
else
  print_success "Yay is already installed."
fi

# -----------------------------------------------------------------------------
# STEP 3: Install core system packages via pacman
# -----------------------------------------------------------------------------
print_header "Installing core packages (pacman)..."

PACMAN_PACKAGES=(
  # Core Hyprland & Wayland tools
  hyprland hyprpaper hyprlock hypridle xdg-desktop-portal-hyprland

  # Wallpaper and color tools
  swww python-pywal

  # Terminal, utilities, and system tools
  kitty waybar starship cliphist brightnessctl pamixer

  # File management
  thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb yazi

  # Fonts
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono \
  ttf-fira-sans ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols \
  ttf-nerd-fonts-symbols-mono

  # Extras
  polkit polkit-gnome papirus-icon-theme nano tar firefox mpv code gnome-disk-utility dunst

  # Display manager
  sddm
)

run_command "pacman -S --noconfirm ${PACMAN_PACKAGES[*]}" "Install core system packages" "no"

# Enable polkit and SDDM
run_command "systemctl enable --now polkit.service" "Enable polkit" "no"
run_command "systemctl enable sddm.service" "Enable SDDM display manager" "no"

# -----------------------------------------------------------------------------
# STEP 4: Install AUR packages via yay
# -----------------------------------------------------------------------------
print_header "Installing AUR packages..."

AUR_PACKAGES=(
  tofi
  waypaper
)

run_command "sudo -u $SUDO_USER yay -S --noconfirm --sudoloop ${AUR_PACKAGES[*]}" \
  "Install AUR utilities" "no" "no"

# -----------------------------------------------------------------------------
# STEP 5: Copy wallpapers and assets
# -----------------------------------------------------------------------------
print_header "Copying wallpapers and assets..."

ASSETS_SRC="$SCRIPT_DIR/../assets"
ASSETS_DEST="$USER_HOME/.config/assets"

if [[ -d "$ASSETS_SRC/wallpapers" ]]; then
  run_command "mkdir -p \"$ASSETS_DEST\"" "Create assets destination" "no"
  run_command "cp -r \"$ASSETS_SRC/wallpapers\" \"$ASSETS_DEST\"" "Copy wallpapers to config directory" "no"
  run_command "chown -R $SUDO_USER:$SUDO_USER \"$ASSETS_DEST\"" "Fix ownership of assets" "no"
else
  print_warning "No wallpapers found at $ASSETS_SRC/wallpapers"
fi

# -----------------------------------------------------------------------------
# STEP 6: Install Monochrome SDDM theme
# -----------------------------------------------------------------------------
print_header "Installing Monochrome SDDM theme..."

MONO_SDDM_REPO="https://github.com/pwyde/monochrome-kde.git"
MONO_SDDM_TEMP="$(mktemp -d)"
MONO_THEME_NAME="monochrome"

# Ensure /tmp exists and has correct permissions
if [[ ! -d "/tmp" ]]; then
  print_warning "/tmp was missing. Creating it now..."
  mkdir -p /tmp
  chmod 1777 /tmp
fi

# Clone theme safely
run_command "git clone --depth=1 \"$MONO_SDDM_REPO\" \"$MONO_SDDM_TEMP\"" \
  "Clone Monochrome SDDM theme"

if [[ ! -d \"$MONO_SDDM_TEMP/sddm/themes/$MONO_THEME_NAME\" ]]; then
  print_error "Monochrome theme clone failed: directory not found!"
  exit 1
fi

# Copy theme into SDDM themes folder
run_command "cp -r \"$MONO_SDDM_TEMP/sddm/themes/$MONO_THEME_NAME\" \"/usr/share/sddm/themes/$MONO_THEME_NAME\"" \
  "Copy Monochrome theme to SDDM directory"

# Fix permissions
run_command "chown -R root:root \"/usr/share/sddm/themes/$MONO_THEME_NAME\"" "Fix SDDM theme permissions"

# Configure SDDM to use Monochrome
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=$MONO_THEME_NAME" > /etc/sddm.conf.d/10-theme.conf

# Clean up
rm -rf "$MONO_SDDM_TEMP"

print_success "Monochrome SDDM theme installed successfully!"

# -----------------------------------------------------------------------------
# STEP 7: GPU driver detection and install
# -----------------------------------------------------------------------------
print_header "Detecting and installing GPU drivers..."

GPU_INFO=$(lspci | grep -Ei "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
  run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers" "no"
elif echo "$GPU_INFO" | grep -qi "amd"; then
  run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers" "no"
elif echo "$GPU_INFO" | grep -qi "intel"; then
  run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers" "no"
else
  print_warning "No supported GPU detected. Info: $GPU_INFO"
fi

# -----------------------------------------------------------------------------
# STEP 8: Final messages
# -----------------------------------------------------------------------------
print_bold_blue "\n✅ Setup Complete!"
echo "You can now reboot to start Hyprland with SDDM and begin using Waypaper for wallpapers."
