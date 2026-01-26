#!/bin/bash
# Full Hyprland Installer – 2026 AMD Optimized
# Fixes: Yay permissions, Core package naming, and UI initialization
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
WAL_CACHE="$USER_HOME/.cache/wal"

# Check root
[[ "$EUID" -eq 0 ]] || print_error "Please run with: sudo $0"

# ----------------------------
# 1. System Update & AMD Drivers
# ----------------------------
print_header "Step 1: System Update & AMD Drivers"
run_command "pacman -Syu --noconfirm" "Full system upgrade"
run_command "pacman -S --noconfirm --needed mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu linux-headers" "Install AMD GPU stack"

# ----------------------------
# 2. Core Packages (The "Bork" Prevention List)
# ----------------------------
print_header "Step 2: Core Packages"

# We split these to avoid one failed package name killing the whole install
CORE_UI=(hyprland waybar swww mako kitty kitty-terminfo sddm)
TOOLS=(grim slurp btop jq wget curl bluez bluez-utils blueman pavucontrol firefox gvfs udiskie starship fastfetch)
YAZI_STACK=(yazi ffmpegthumbnailer poppler imagemagick chafa)
FONTS=(ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code)

run_command "pacman -S --noconfirm --needed ${CORE_UI[*]}" "Core UI install"
run_command "pacman -S --noconfirm --needed ${TOOLS[*]}" "Tools install"
run_command "pacman -S --noconfirm --needed ${YAZI_STACK[*]}" "Yazi stack install"
run_command "pacman -S --noconfirm --needed ${FONTS[*]}" "Fonts install"

# Polkit Fallback (Handles naming changes between polkit-kde-agent and polkit-kde-agent-1)
print_header "Installing Polkit"
if ! pacman -S --noconfirm --needed polkit-kde-agent; then
    pacman -S --noconfirm --needed polkit-kde-agent-1 || echo "Warning: Polkit agent install failed, check mirrors."
fi

# ----------------------------
# 3. Yay & AUR (Write Permission Fix)
# ----------------------------
print_header "Step 3: Yay & AUR Helper"
if ! command -v yay &>/dev/null; then
    run_command "pacman -S --noconfirm --needed git base-devel" "Install build dependencies"
    
    # Create build dir and give ownership to the user
    BUILD_DIR="/tmp/yay_build_$(date +%s)"
    mkdir -p "$BUILD_DIR"
    chown -R "$USER_NAME:$USER_NAME" "$BUILD_DIR"
    
    # Build as user
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
    (cd "$BUILD_DIR/yay" && sudo -u "$USER_NAME" makepkg -si --noconfirm)
    
    rm -rf "$BUILD_DIR"
fi

# Install Pywal16
run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "Install Pywal16 from AUR"

# ----------------------------
# 4. Configs & Symlinks
# ----------------------------
print_header "Step 4: Applying Configs"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,mako,scripts,wal/templates} "$WAL_CACHE"

# Copy from repo root
[[ -d "$REPO_ROOT/configs/hypr" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/hypr"/* "$CONFIG_DIR/hypr/"
[[ -d "$REPO_ROOT/configs/waybar" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/waybar"/* "$CONFIG_DIR/waybar/"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"

# Setup Symlinks for Pywal
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# ----------------------------
# 5. Initialization (The "Waybar Fix")
# ----------------------------
print_header "Step 5: Initializing Colors"
# Check for wallpapers
WALL_DIR="$USER_HOME/Pictures/Wallpapers"
if [[ -d "$REPO_ROOT/Pictures/Wallpapers" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures"
    sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"
fi

# Run Wal once to create the files that Waybar expects
FIRST_WALL=$(find "$WALL_DIR" -type f | head -n 1 || true)
if [[ -n "$FIRST_WALL" ]]; then
    sudo -u "$USER_NAME" wal -i "$FIRST_WALL" -q
    print_success "Colors initialized from $FIRST_WALL"
else
    echo "Warning: No wallpapers found. Waybar will look broken until you run 'wal -i'."
fi

# ----------------------------
# 6. Finalizing Services
# ----------------------------
print_header "Step 6: Enabling Services"
systemctl enable --now bluetooth.service || true

# SDDM Fix
if [ -f /usr/lib/systemd/system/sddm.service ]; then
    systemctl enable sddm.service
else
    pacman -S --noconfirm sddm && systemctl enable sddm.service
fi

print_success "🎉 DONE! Reboot your machine now."
