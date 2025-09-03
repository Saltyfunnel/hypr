#!/bin/bash
set -euo pipefail

# ------------------------
# Variables
# ------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="/home/$USER_NAME"

ASSETS_SRC="$SCRIPT_DIR/../assets"
CONFIGS_SRC="$SCRIPT_DIR/../configs"
SCRIPTS_SRC="$SCRIPT_DIR/../scripts"
ASSETS_DEST="$USER_HOME/.config/assets"
CONFIGS_DEST="$USER_HOME/.config"
SCRIPTS_DEST="$USER_HOME/.config/scripts"

# ------------------------
# Helper functions
# ------------------------
print_info()    { echo -e "\033[0;34m$1\033[0m"; }
print_success() { echo -e "\033[0;32m$1\033[0m"; }
print_warning() { echo -e "\033[0;33m$1\033[0m"; }
print_error()   { echo -e "\033[0;31m$1\033[0m"; }
print_header()  { echo -e "\n\033[1;34m==> $1\033[0m"; }

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    print_error "Please run this script as root."
    exit 1
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "arch" ]]; then
      print_warning "This script is designed for Arch Linux. Detected: $PRETTY_NAME"
    else
      print_success "Arch Linux detected. Proceeding."
    fi
  else
    print_warning "/etc/os-release not found. Cannot determine OS."
  fi
}

run_command() {
  local cmd="$1"
  local description="$2"

  print_info "Running: $cmd"
  if ! eval "$cmd"; then
    print_error "Failed: $description"
    exit 1
  else
    print_success "$description completed successfully."
  fi
}

# ------------------------
# Start install
# ------------------------
check_root
check_os

print_header "Starting Full Hyprland Setup"

# ------------------------
# Step 1: Update system
# ------------------------
run_command "pacman -Syyu --noconfirm" "System package update"

# ------------------------
# Step 2: GPU detection and drivers
# ------------------------
print_header "Detecting GPU..."
GPU_INFO=$(lspci | grep -Ei "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_info "NVIDIA GPU detected."
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_info "AMD GPU detected."
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_info "Intel GPU detected."
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected. Info: $GPU_INFO"
    print_warning "Skipping GPU driver installation."
fi

# ------------------------
# Step 3: Install yay if missing
# ------------------------
if ! command -v yay &>/dev/null; then
  print_info "Yay not found. Installing..."
  run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
  run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository"
  run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix yay directory permissions"
  run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay"
  run_command "rm -rf /tmp/yay" "Clean up yay directory"
else
  print_success "Yay is already installed."
fi

# ------------------------
# Step 4: Install pacman packages
# ------------------------
PACMAN_PACKAGES=(
  hyprland waybar swww starship firefox cliphist thunar kitty yazi
  thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
  gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb polkit polkit-gnome nano tar code mpv dunst
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
  ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
  sddm
)

run_command "pacman -S --noconfirm ${PACMAN_PACKAGES[*]}" "Install core system packages"

# Enable polkit and SDDM
run_command "systemctl enable --now polkit.service" "Enable polkit"
run_command "systemctl enable sddm.service" "Enable SDDM"

# ------------------------
# Step 5: Install AUR packages
# ------------------------
AUR_PACKAGES=(
  waypaper
  python-pywal
)

run_command "sudo -u $USER_NAME yay -S --noconfirm --sudoloop ${AUR_PACKAGES[*]}" "Install AUR packages"

# ------------------------
# Step 6: Copy wallpapers and assets
# ------------------------
if [[ -d "$ASSETS_SRC/wallpapers" ]]; then
  run_command "mkdir -p \"$ASSETS_DEST\"" "Create assets directory"
  run_command "cp -r \"$ASSETS_SRC/wallpapers\" \"$ASSETS_DEST\"" "Copy wallpapers"
  run_command "chown -R $USER_NAME:$USER_NAME \"$ASSETS_DEST\"" "Fix ownership of assets"
else
  print_warning "No wallpapers found in $ASSETS_SRC/wallpapers"
fi

# ------------------------
# Step 7: Copy configs
# ------------------------
if [[ -d "$CONFIGS_SRC" ]]; then
  run_command "mkdir -p \"$CONFIGS_DEST\"" "Create config directory"
  run_command "cp -r \"$CONFIGS_SRC/\"* \"$CONFIGS_DEST/\"" "Copy configuration files"
  run_command "chown -R $USER_NAME:$USER_NAME \"$CONFIGS_DEST\"" "Fix ownership of configs"
else
  print_warning "No configs folder found at $CONFIGS_SRC"
fi

# ------------------------
# Step 8: Copy user scripts (themes-wallpaper.sh)
# ------------------------
if [[ -d "$SCRIPTS_SRC" ]]; then
  run_command "mkdir -p \"$SCRIPTS_DEST\"" "Create scripts directory"
  run_command "cp -r \"$SCRIPTS_SRC/\"* \"$SCRIPTS_DEST/\"" "Copy user scripts"
  run_command "chown -R $USER_NAME:$USER_NAME \"$SCRIPTS_DEST\"" "Fix ownership of scripts"
else
  print_warning "No scripts folder found at $SCRIPTS_SRC"
fi

# ------------------------
# Finish
# ------------------------
print_header "✅ Full setup complete!"
echo "Reboot to start Hyprland with SDDM. Waypaper, Yazi, and themes-wallpaper.sh are installed for wallpaper management."
