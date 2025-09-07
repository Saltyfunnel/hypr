#!/bin/bash
# Hyprland Setup Script for Arch Linux (Non-interactive, no GTK)
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
        print_warning "Skipping $name - source missing: $src"
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
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"

# =====================================
# Pre-run Checks
# =====================================
[[ "$EUID" -eq 0 ]] || print_error "This script must be run as root (sudo $0)"
[[ -d "$REPO_ROOT/configs" ]] || print_error "Missing configs folder at $REPO_ROOT/configs"
command -v git &>/dev/null || print_error "git not installed. Install: sudo pacman -S git"
command -v curl &>/dev/null || print_error "curl not installed. Install: sudo pacman -S curl"

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
# Core Pacman Packages
# =====================================
print_header "Installing Core Packages"
PACMAN_PACKAGES=(
    hyprland waybar swww dunst grim slurp kitty nano rofi wget jq
    thunar gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 chafa
    thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    firefox yazi fastfetch mpv
    qt5-wayland qt6-wayland gtk3 gtk4 starship
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Core package installation"

# Enable essential services
run_command "systemctl enable --now polkit.service" "Enable polkit"
run_command "systemctl enable sddm.service" "Enable SDDM"

# =====================================
# Install Yay (AUR Helper)
# =====================================
print_header "Installing yay"
if command -v yay &>/dev/null; then
    print_success "Yay already installed"
else
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Set permissions for yay build"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay"
    run_command "rm -rf /tmp/yay" "Clean up temporary yay files"
fi

# =====================================
# Install AUR Packages (Matugen)
# =====================================
print_header "Installing AUR Packages"
AUR_PACKAGES=( matugen-bin vscodium-bin )
run_command "sudo -u $USER_NAME yay -S --noconfirm --needed --sudoloop --mflags '--noconfirm --skippgpcheck' ${AUR_PACKAGES[*]}" "AUR package installation"

# =====================================
# Copy Configuration Files
# =====================================
print_header "Copying Configurations"
copy_configs "$REPO_ROOT/configs/hypr"   "$CONFIG_DIR/hypr"   "Hyprland"
copy_configs "$REPO_ROOT/configs/waybar" "$CONFIG_DIR/waybar" "Waybar"
copy_configs "$REPO_ROOT/configs/theme-wallpaper" "$CONFIG_DIR/theme-wallpaper" "Theme Wallpaper"

# =====================================
# Copy Scripts and Make Executable
# =====================================
print_header "Copying Scripts"
SCRIPT_DEST="$USER_HOME/.local/bin"
sudo -u "$USER_NAME" mkdir -p "$SCRIPT_DEST"
sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/scripts/." "$SCRIPT_DEST"
sudo -u "$USER_NAME" chmod +x "$SCRIPT_DEST/"*
print_success "✅ Scripts copied and made executable to $SCRIPT_DEST"

# =====================================
# Copy Wallpapers
# =====================================
print_header "Copying Wallpapers"
WALLPAPER_SRC_DIR="$REPO_ROOT/assets/wallpapers"
WALLPAPER_DEST_DIR="$USER_HOME/Pictures/Wallpapers"
sudo -u "$USER_NAME" mkdir -p "$WALLPAPER_DEST_DIR"
sudo -u "$USER_NAME" cp -rf "$WALLPAPER_SRC_DIR/." "$WALLPAPER_DEST_DIR"
print_success "✅ All wallpapers copied to $WALLPAPER_DEST_DIR"

# =====================================
# Update Bashrc for Matugen
# =====================================
print_header "Updating Bashrc for Matugen"
BASHRC="$USER_HOME/.bashrc"
if ! grep -q "theme-wallpaper" "$BASHRC"; then
    echo "" >> "$BASHRC"
    echo "# Matugen Theme-Wallpaper Scripts" >> "$BASHRC"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$BASHRC"
    echo "alias theme-wallpaper='~/.config/theme-wallpaper/theme-wallpaper.sh'" >> "$BASHRC"
    print_success "✅ Added theme-wallpaper alias to $BASHRC"
else
    print_warning "theme-wallpaper alias already present in $BASHRC"
fi

# =====================================
# Final Message
# =====================================
print_header "Setup Complete!"
print_success "🎉 Reboot and log in via SDDM to start using Hyprland with your configs."
print_success "You can now run the theme scripts with:"
echo "theme-wallpaper"
