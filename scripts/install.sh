#!/bin/bash
# Minimal Hyprland Installer with user configs (fixed paths)
set -euo pipefail

# ----------------------------
# Helper functions
# ----------------------------
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

# ----------------------------
# Setup Variables
# ----------------------------
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"

# repo root is the parent folder of the script
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HYPR_CONFIG_SRC="$REPO_ROOT/configs/hypr/hyprland.conf"
WAYBAR_CONFIG_SRC="$REPO_ROOT/configs/waybar"
SCRIPTS_SRC="$REPO_ROOT/scripts"

# ----------------------------
# Checks
# ----------------------------
[[ "$EUID" -eq 0 ]] || print_error "Run as root (sudo $0)"
command -v pacman &>/dev/null || print_error "pacman not found"
command -v systemctl &>/dev/null || print_error "systemctl not found"

print_success "✅ Environment checks passed"

# ----------------------------
# System Update
# ----------------------------
print_header "Updating system"
run_command "pacman -Syyu --noconfirm" "System update"

# ----------------------------
# GPU Drivers
# ----------------------------
print_header "Detecting GPU"
GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    run_command "pacman -S --noconfirm nvidia nvidia-utils" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi amd; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu mesa vulkan-radeon" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi intel; then
    run_command "pacman -S --noconfirm mesa vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected. Skipping driver installation."
fi

# ----------------------------
# Core Packages
# ----------------------------
print_header "Installing core packages"
PACMAN_PACKAGES=(
    hyprland waybar swww dunst grim slurp kitty nano wget jq
    sddm polkit polkit-kde-agent code curl
    thunar gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 chafa
    thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    firefox yazi fastfetch mpv gnome-disk-utility
    qt5-wayland qt6-wayland gtk3 gtk4 starship
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Install core packages"

# Enable essential services
run_command "systemctl enable --now polkit.service" "Enable polkit"

# ----------------------------
# Install Yay (AUR Helper)
# ----------------------------
print_header "Installing Yay"
if command -v yay &>/dev/null; then
    print_success "Yay already installed"
else
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git + base-devel"
    run_command "rm -rf /tmp/yay" "Remove old yay folder"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Set permissions for yay build"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay"
    run_command "rm -rf /tmp/yay" "Clean up temporary yay files"
fi

# ----------------------------
# Install AUR Packages
# ----------------------------
print_header "Installing AUR packages"

# List of AUR packages to install
AUR_PACKAGES=(
    python-pywal16
    # Add additional AUR packages here
)

for pkg in "${AUR_PACKAGES[@]}"; do
    if yay -Qs "^$pkg$" &>/dev/null; then
        print_success "✅ $pkg is already installed"
    else
        run_command "sudo -u $USER_NAME yay -S --noconfirm $pkg" "Install $pkg from AUR"
    fi
done

# ----------------------------
# Copy Hyprland config
# ----------------------------
print_header "Copying Hyprland config"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/hypr"
if [[ -f "$HYPR_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$HYPR_CONFIG_SRC" "$CONFIG_DIR/hypr/hyprland.conf"
    print_success "✅ Copied hyprland.conf to $CONFIG_DIR/hypr/"
else
    print_warning "Hyprland config not found at $HYPR_CONFIG_SRC, skipping"
fi

# ----------------------------
# Copy Waybar config + style
# ----------------------------
print_header "Copying Waybar config"
if [[ -d "$WAYBAR_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/waybar"
    sudo -u "$USER_NAME" cp -rf "$WAYBAR_CONFIG_SRC/." "$CONFIG_DIR/waybar/"
    print_success "✅ Waybar config and style copied to $CONFIG_DIR/waybar/"
else
    print_warning "Waybar config folder not found at $WAYBAR_CONFIG_SRC, skipping"
fi

# ----------------------------
# Copy Yazi config
# ----------------------------
print_header "Copying Yazi config"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/yazi"

YAZI_FILES=("yazi.toml" "keybind.toml" "theme.toml")

for file in "${YAZI_FILES[@]}"; do
    SRC="$REPO_ROOT/configs/yazi/$file"
    DEST="$CONFIG_DIR/yazi/$file"

    if [[ -f "$SRC" ]]; then
        sudo -u "$USER_NAME" cp "$SRC" "$DEST"
        print_success "✅ $file copied to $CONFIG_DIR/yazi/"
    else
        print_warning "$file not found at $SRC, skipping"
    fi
done

# ----------------------------
# Copy user scripts (setwallpaper etc.)
# ----------------------------
print_header "Copying user scripts"
if [[ -d "$SCRIPTS_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/scripts"
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC/." "$CONFIG_DIR/scripts/"
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*.sh
    print_success "✅ User scripts copied to $CONFIG_DIR/scripts/"
else
    print_warning "Scripts folder not found at $SCRIPTS_SRC, skipping"
fi

# ----------------------------
# Copy Fastfetch config
# ----------------------------
print_header "Copying Fastfetch config"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/fastfetch"

FASTFETCH_SRC="$REPO_ROOT/configs/fastfetch/config.jsonc"
FASTFETCH_DEST="$CONFIG_DIR/fastfetch/config.jsonc"

if [[ -f "$FASTFETCH_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$FASTFETCH_SRC" "$FASTFETCH_DEST"
    print_success "✅ Fastfetch config.jsonc copied to $CONFIG_DIR/fastfetch/"
else
    print_warning "Fastfetch config.jsonc not found at $FASTFETCH_SRC, skipping"
fi

# ----------------------------
# Copy .bashrc
# ----------------------------
print_header "Copying .bashrc"
if [[ -f "$REPO_ROOT/configs/.bashrc" ]]; then
    sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/.bashrc" "$USER_HOME/.bashrc"
    print_success "✅ .bashrc copied to $USER_HOME/"
else
    print_warning ".bashrc not found in $REPO_ROOT/configs/, skipping"
fi

# ----------------------------
# Copy Wallpapers to ~/Pictures
# ----------------------------
print_header "Copying Wallpapers"
WALLPAPER_SRC="$REPO_ROOT/Pictures/Wallpapers"
PICTURES_DEST="$USER_HOME/Pictures"

if [[ -d "$WALLPAPER_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$PICTURES_DEST"
    sudo -u "$USER_NAME" cp -rf "$WALLPAPER_SRC" "$PICTURES_DEST/"
    print_success "✅ Wallpapers copied to $PICTURES_DEST/Wallpapers/"
else
    print_warning "Wallpapers folder not found at $WALLPAPER_SRC, skipping"
fi

# ----------------------------
# Enable SDDM
# ----------------------------
print_header "Setting up SDDM"
run_command "systemctl enable s
