#!/bin/bash
# Hyprland Setup Script for Arch Linux
set -euo pipefail

# =====================================
# Helper Functions
# =====================================
print_header()    { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success()   { echo -e "\e[32m$1\e[0m"; }
print_warning()   { echo -e "\e[33mWarning: $1\e[0m" >&2; }
print_error()     { echo -e "\e[31mError: $1\e[0m" >&2; exit 1; }

run_command() {
    local cmd="$1"
    local desc="$2"

    if [[ "$CONFIRMATION" == "yes" ]]; then
        read -p "Proceed with: $desc? (Press Enter to continue or Ctrl+C to abort) "
    fi

    echo -e "\nRunning: $desc"
    if ! eval "$cmd"; then
        print_error "Failed: $desc"
    fi
    print_success "✅ Success: $desc"
}

copy_configs() {
    local src="$1"
    local dest="$2"
    local name="$3"

    if [[ ! -d "$src" ]]; then
        print_warning "Skipping $name - source folder missing: $src"
        return
    fi

    sudo -u "$USER_NAME" mkdir -p "$dest"
    sudo -u "$USER_NAME" cp -rf "$src/." "$dest/"
    print_success "✅ $name config copied to $dest"
}

# =====================================
# Setup Variables
# =====================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
CONFIRMATION="yes" # default interactive mode

# Check for --noconfirm flag
if [[ $# -eq 1 && "$1" == "--noconfirm" ]]; then
    CONFIRMATION="no"
elif [[ $# -gt 0 ]]; then
    echo "Usage: $0 [--noconfirm]"
    exit 1
fi

# =====================================
# Pre-run Checks
# =====================================
if [[ "$EUID" -ne 0 ]]; then
    print_error "This script must be run as root. Try: sudo $0"
fi

print_header "Checking Environment"

[[ -d "$SCRIPT_DIR/configs" ]] || print_error "Missing configs folder at $SCRIPT_DIR/configs"
command -v git &>/dev/null || print_error "git not installed. Install with: sudo pacman -S git"
command -v curl &>/dev/null || print_error "curl not installed. Install with: sudo pacman -S curl"

print_success "✅ Environment checks passed"

# =====================================
# Base System Update
# =====================================
print_header "Updating System"
run_command "pacman -Syyu --noconfirm" "System package update"

# =====================================
# GPU Driver Installation
# =====================================
print_header "Detecting and Installing GPU Drivers"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_success "NVIDIA GPU detected"
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_success "AMD GPU detected"
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_success "Intel GPU detected"
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Intel drivers"
else
    print_warning "No supported GPU detected. Skipping driver installation."
fi

# =====================================
# Install Core Pacman Packages
# =====================================
print_header "Installing Core Packages"

PACMAN_PACKAGES=(
    hyprland waybar swww dunst grim slurp kitty nano rofi wget jq
    sddm polkit polkit-kde-agent
    thunar gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2
    thunar-archive-plugin thunar-volman ffmpegthumbnailer file-roller tumbler
    lite-xl firefox yazi fastfetch mpv
    qt5-wayland qt6-wayland
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
)

run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Core package installation"

# Enable essential services
run_command "systemctl enable --now polkit.service" "Enable polkit"
run_command "systemctl enable sddm.service" "Enable SDDM"

# =====================================
# Install Yay (AUR Helper)
# =====================================
print_header "Installing yay (AUR Helper)"

if command -v yay &>/dev/null; then
    print_success "Yay is already installed"
else
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Set permissions for yay build"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay as user"
    run_command "rm -rf /tmp/yay" "Clean up temporary yay files"
fi

# =====================================
# Install AUR Packages
# =====================================
print_header "Installing AUR Packages"
AUR_PACKAGES=( python-pywalfox )

if [[ ${#AUR_PACKAGES[@]} -gt 0 ]]; then
    run_command "sudo -u $USER_NAME yay -S --noconfirm --sudoloop ${AUR_PACKAGES[*]}" "AUR package installation"
fi

# =====================================
# Copy Configuration Files
# =====================================
print_header "Copying Configurations"

copy_configs "$SCRIPT_DIR/configs/hypr"   "$CONFIG_DIR/hypr"   "Hyprland"
copy_configs "$SCRIPT_DIR/configs/waybar" "$CONFIG_DIR/waybar" "Waybar"

# =====================================
# Final Message
# =====================================
print_header "Setup Complete!"
print_success "🎉 Reboot and log in via SDDM to start using Hyprland with your custom configs."
