#!/bin/bash
# Full Hyprland Installer – 2026 AMD Optimized (Complete Version)
# Fixes: Missing apps, Yay permissions, and Template copying
set -euo pipefail

# ----------------------------
# Helper functions
# ----------------------------
print_header() { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success() { echo -e "\e[32m$1\e[0m"; }
print_error() { echo -e "\e[31mError: $1\e[0m" >&2; exit 1; }

run_command() {
    local cmd="$1"
    local desc="$2"
    echo -e "\nRunning: $desc"
    if ! eval "$cmd"; then print_error "Failed: $desc"; fi
    print_success "✅ Success: $desc"
}

# ----------------------------
# Setup Variables
# ----------------------------
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAL_TEMPLATES="$CONFIG_DIR/wal/templates"
WAL_CACHE="$USER_HOME/.cache/wal"

# Check root
[[ "$EUID" -eq 0 ]] || print_error "Please run with: sudo $0"

# ----------------------------
# 1. System Update & AMD Drivers
# ----------------------------
print_header "Step 1: System Update & AMD Drivers"
run_command "pacman -Syu --noconfirm" "Full system upgrade"
run_command "pacman -S --noconfirm --needed mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu linux-headers" "AMD GPU stack"

# ----------------------------
# 2. Complete Core Packages
# ----------------------------
print_header "Step 2: Complete Core Package Stack"

PACMAN_PACKAGES=(
    # Desktop Environment
    hyprland waybar swww mako grim slurp kitty nano wget jq btop sddm
    code curl bluez bluez-utils blueman python-pyqt6 python-pillow
    gvfs udiskie udisks2 firefox fastfetch starship mpv gnome-disk-utility pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2 trash-cli
    
    # Archives
    unzip p7zip tar gzip xz bzip2 unrar atool
    
    # Yazi & Image Preview Stack
    yazi ffmpegthumbnailer poppler imagemagick chafa imv
    
    # Fonts
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono ttf-cascadia-code-nerd
)

run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Install all core apps"

# Polkit Check
if ! pacman -S --noconfirm --needed polkit-kde-agent; then
    pacman -S --noconfirm --needed polkit-kde-agent-1 || echo "Polkit agent fallback failed."
fi

# ----------------------------
# 3. Yay & AUR (Permission Fix)
# ----------------------------
print_header "Step 3: Yay & Pywal16"
if ! command -v yay &>/dev/null; then
    run_command "pacman -S --noconfirm --needed git base-devel" "Install build dependencies"
    BUILD_DIR="/tmp/yay_build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    chown -R "$USER_NAME:$USER_NAME" "$BUILD_DIR"
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
    (cd "$BUILD_DIR/yay" && sudo -u "$USER_NAME" makepkg -si --noconfirm)
    rm -rf "$BUILD_DIR"
fi
run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "AUR Packages"

# ----------------------------
# 4. Applying Templates & Configs (The Fix)
# ----------------------------
print_header "Step 4: Applying Templates and Configs"

# Ensure directories exist
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts,wal/templates} "$WAL_CACHE"

# Copy Templates from Repo to ~/.config/wal/templates
if [[ -d "$REPO_ROOT/configs/wal/templates" ]]; then
    sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/wal/templates"/* "$WAL_TEMPLATES/"
    print_success "✅ Pywal templates copied."
fi

# Copy Other Configs
[[ -d "$REPO_ROOT/configs/hypr" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/hypr"/* "$CONFIG_DIR/hypr/"
[[ -d "$REPO_ROOT/configs/waybar" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/waybar"/* "$CONFIG_DIR/waybar/"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"

# Create Symlinks for the apps that use Pywal
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# ----------------------------
# 5. Wallpapers & Initial Run
# ----------------------------
print_header "Step 5: Wallpapers & Color Init"
if [[ -d "$REPO_ROOT/Pictures/Wallpapers" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures"
    sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"
fi

# Run Wal to generate the files BEFORE logging in
FIRST_WALL=$(find "$USER_HOME/Pictures/Wallpapers" -type f | head -n 1 || true)
if [[ -n "$FIRST_WALL" ]]; then
    sudo -u "$USER_NAME" wal -i "$FIRST_WALL" -q
    print_success "Colors initialized."
fi

# ----------------------------
# 6. Final Services
# ----------------------------
print_header "Step 6: Services"
systemctl enable --now bluetooth.service || true

if [ -f /usr/lib/systemd/system/sddm.service ]; then
    systemctl enable sddm.service
else
    pacman -S --noconfirm sddm && systemctl enable sddm.service
fi

print_success "🎉 Complete. Reboot now."
