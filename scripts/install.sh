#!/bin/bash
# Hyprland Setup Script for Arch Linux (Non-interactive)
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
    # Force overwrite even if dest is not empty
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
    hyprland waybar swww dunst grim slurp kitty nano wget jq
    sddm polkit polkit-kde-agent code
    thunar gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 chafa
    thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    firefox yazi fastfetch mpv
    qt5-wayland qt6-wayland gtk3 gtk4 fastfetch starship
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Core package installation"

# Enable essential services
run_command "systemctl enable --now polkit.service" "Enable polkit"

# =====================================
# Install Yay (AUR Helper)
# =====================================
print_header "Installing yay"
if command -v yay &>/dev/null; then
    print_success "Yay already installed"
else
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
    
    # Remove old yay dir to prevent conflicts
    run_command "rm -rf /tmp/yay" "Clean up existing yay folder if present"
    
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Set permissions for yay build"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay"
    run_command "rm -rf /tmp/yay" "Clean up temporary yay files"
fi

# =====================================
# Install AUR Packages
# =====================================
print_header "Installing AUR Packages"
AUR_PACKAGES=( tofi )
run_command "sudo -u $USER_NAME yay -S --noconfirm --needed --sudoloop --mflags '--noconfirm --skippgpcheck' ${AUR_PACKAGES[*]}" "AUR package installation"

# =====================================
# Copy Configuration Files
# =====================================
print_header "Copying Configurations"
copy_configs "$REPO_ROOT/configs/hypr"        "$CONFIG_DIR/hypr"        "Hyprland"
copy_configs "$REPO_ROOT/configs/waybar"      "$CONFIG_DIR/waybar"      "Waybar"
copy_configs "$REPO_ROOT/configs/kitty"       "$CONFIG_DIR/kitty"       "Kitty"
copy_configs "$REPO_ROOT/configs/fastfetch"   "$CONFIG_DIR/fastfetch"   "Fastfetch"
copy_configs "$REPO_ROOT/configs/dunst"       "$CONFIG_DIR/dunst"       "dunst"
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
# Force overwrite
sudo -u "$USER_NAME" cp -rf "$WALLPAPER_SRC_DIR/." "$WALLPAPER_DEST_DIR"
print_success "✅ All wallpapers copied to $WALLPAPER_DEST_DIR"

# =====================================
# Configure Starship for Bash
# =====================================
print_header "Configuring Starship prompt"
BASHRC_FILE="$USER_HOME/.bashrc"
STARSHIP_INIT='eval "$(starship init bash)"'
if ! grep -Fxq "$STARSHIP_INIT" "$BASHRC_FILE"; then
    echo -e "\n# Initialize Starship prompt\n$STARSHIP_INIT" >> "$BASHRC_FILE"
    print_success "✅ Starship initialization added to $BASHRC_FILE"
else
    print_success "✅ Starship already initialized in $BASHRC_FILE"
fi

# =====================================
# Install and Enable SDDM (Re-run Safe)
# =====================================
print_header "Installing and Enabling SDDM"

# Ensure SDDM package is installed
run_command "pacman -S --noconfirm --needed sddm" "Install SDDM display manager"

# Check if the sddm.service file exists
if systemctl list-unit-files | grep -q '^sddm.service'; then
    # Check if SDDM is already enabled
    if systemctl is-enabled sddm.service &>/dev/null; then
        print_success "✅ SDDM is already enabled"
    else
        run_command "systemctl enable --now sddm.service" "Enable and start SDDM login manager"
    fi

    # Check if default target is already graphical
    CURRENT_TARGET=$(systemctl get-default)
    if [[ "$CURRENT_TARGET" != "graphical.target" ]]; then
        run_command "systemctl set-default graphical.target" "Set default target to graphical"
        print_success "✅ Default target set to graphical.target"
    else
        print_success "✅ Default target already set to graphical.target"
    fi
else
    print_warning "SDDM service not found even after install, skipping enable step"
fi

# =====================================
# Final Message
# =====================================
print_header "Setup Complete!"
print_success "🎉 Reboot and log in via SDDM (if installed) to start using Hyprland with your configs."
print_success "You can now generate colorschemes with Matugen by running:"
echo "matugen image --file \"$WALLPAPER_DEST_DIR/cats.png\" --out-dir \"$CONFIG_DIR/matugen\""
