#!/bin/bash
# Full Hyprland Installer – 2026 AMD (Final Fix Version)
set -euo pipefail

# ----------------------------
# Helper functions
# ----------------------------
print_header() { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success() { echo -e "\e[32m$1\e[0m"; }
print_warning() { echo -e "\e[33mWarning: $1\e[0m" >&2; }
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
SCRIPTS_SRC="$REPO_ROOT/scripts"
WAL_TEMPLATES="$CONFIG_DIR/wal/templates"
WAL_CACHE="$USER_HOME/.cache/wal"

# Check root
[[ "$EUID" -eq 0 ]] || print_error "Please run with: sudo $0"

# ----------------------------
# 1. System & Drivers
# ----------------------------
print_header "Step 1: System Update & AMD Drivers"
run_command "pacman -Syu --noconfirm" "Full system upgrade"
run_command "pacman -S --noconfirm --needed mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu linux-headers" "AMD GPU stack"

# ----------------------------
# 2. The Full Package Stack
# ----------------------------
print_header "Step 2: Installing All Apps"
PACMAN_PACKAGES=(
    hyprland waybar swww mako grim slurp kitty sddm code firefox
    bluez bluez-utils blueman pavucontrol fastfetch starship
    gvfs udiskie udisks2 gnome-disk-utility btop jq wget curl trash-cli
    python-pyqt6 python-pillow base-devel git
    unzip p7zip tar gzip xz bzip2 unrar
    yazi ffmpegthumbnailer poppler imagemagick chafa imv
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-cascadia-code-nerd
)

if ! pacman -S --noconfirm --needed "${PACMAN_PACKAGES[@]}" polkit-kde-agent-1; then
    print_warning "Retrying with alternative polkit agent..."
    pacman -S --noconfirm --needed "${PACMAN_PACKAGES[@]}" polkit-kde-agent
fi

# ----------------------------
# 3. Yay & AUR (Permission Fix)
# ----------------------------
print_header "Step 3: Yay & Pywal16"
if ! command -v yay &>/dev/null; then
    BUILD_DIR="/tmp/yay_build"
    rm -rf "$BUILD_DIR" && mkdir -p "$BUILD_DIR"
    chown -R "$USER_NAME:$USER_NAME" "$BUILD_DIR"
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
    (cd "$BUILD_DIR/yay" && sudo -u "$USER_NAME" makepkg -si --noconfirm)
fi
run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "Install Pywal16"

# ----------------------------
# 4. Copying Files & Fixing Symlinks
# ----------------------------
print_header "Step 4: Copying Scripts & Templates"

# 1. Create Directories
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,mako,scripts,wal/templates,fastfetch} "$WAL_CACHE"

# 2. REMOVE OLD SYMLINKS FIRST (Prevents "dangling symlink" errors)
sudo -u "$USER_NAME" rm -f "$CONFIG_DIR/waybar/style.css" "$CONFIG_DIR/mako/config" "$CONFIG_DIR/kitty/kitty.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# 3. Copy Repo Configs to ~/.config
[[ -d "$REPO_ROOT/configs/hypr" ]] && sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/configs/hypr"/* "$CONFIG_DIR/hypr/"
[[ -d "$REPO_ROOT/configs/waybar" ]] && sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/configs/waybar"/* "$CONFIG_DIR/waybar/"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"
[[ -d "$REPO_ROOT/configs/kitty" ]] && sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/configs/kitty"/* "$CONFIG_DIR/kitty/"

# 4. Copy Pywal Templates
if [[ -d "$REPO_ROOT/configs/wal/templates" ]]; then
    sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/configs/wal/templates"/* "$WAL_TEMPLATES/"
fi

# 5. Copy Scripts & Fix Permissions
if [[ -d "$SCRIPTS_SRC" ]]; then
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/* "$CONFIG_DIR/scripts/"
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*
fi

# 6. NOW CREATE SYMLINKS (Pointing to the cache)
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# ----------------------------
# 5. Initialization
# ----------------------------
print_header "Step 5: Initialization"

if [[ -d "$REPO_ROOT/Pictures/Wallpapers" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures"
    sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"
fi

FIRST_WALL=$(find "$USER_HOME/Pictures/Wallpapers" -type f | head -n 1 || true)
if [[ -n "$FIRST_WALL" ]]; then
    sudo -u "$USER_NAME" wal -i "$FIRST_WALL" -q
    print_success "Pywal colors generated."
fi

# ----------------------------
# 6. Services
# ----------------------------
print_header "Step 6: Services"
systemctl enable --now bluetooth.service || true
if [ -f /usr/lib/systemd/system/sddm.service ]; then
    systemctl enable sddm.service
else
    pacman -S --noconfirm sddm && systemctl enable sddm.service
fi

print_success "🎉 Done! Everything is synced correctly. Reboot now."
