#!/bin/bash
# Full Hyprland Installer – 2026 AMD + Pywal + Dotfiles
# Optimized for AMD GPU | Fixed: SDDM check, Yay permissions, and Pywal initialization
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

# ----------------------------
# Checks
# ----------------------------
[[ "$EUID" -eq 0 ]] || print_error "Run as root (sudo $0)"
command -v pacman &>/dev/null || print_error "pacman not found"

# ----------------------------
# System Update & AMD Drivers
# ----------------------------
print_header "Updating system & Installing AMD Drivers"
run_command "pacman -Syyu --noconfirm" "System update"

# AMD specific stack (removing Nvidia logic)
run_command "pacman -S --noconfirm mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu linux-headers" "Install AMD Driver Stack"

# ----------------------------
# Core Packages
# ----------------------------
print_header "Installing core packages"
PACMAN_PACKAGES=(
    # Desktop Environment
    hyprland waybar swww mako grim slurp kitty nano wget jq btop
    sddm polkit-kde-agent-1 code curl bluez bluez-utils blueman python-pyqt6 python-pillow
    gvfs udiskie udisks2 firefox fastfetch starship mpv gnome-disk-utility pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2 trash-cli
    unzip p7zip tar gzip xz bzip2 unrar atool imv
    
    # Yazi & Image Preview Stack
    yazi ffmpegthumbnailer poppler imagemagick chafa
    
    # Fonts
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono ttf-cascadia-code-nerd
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Install core packages"

# ----------------------------
# Install Yay & AUR (Permission Fix)
# ----------------------------
print_header "Installing Yay"
if ! command -v yay &>/dev/null; then
    run_command "pacman -S --noconfirm --needed git base-devel" "Base tools"
    
    # Use a specific build directory and ensure user ownership
    BUILD_DIR="/tmp/yay_build"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    chown -R "$USER_NAME:$USER_NAME" "$BUILD_DIR"
    
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
    run_command "(cd $BUILD_DIR/yay && sudo -u $USER_NAME makepkg -si --noconfirm)" "Install Yay as $USER_NAME"
fi

run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "Install Pywal16 from AUR"

# ----------------------------
# Shell Setup
# ----------------------------
print_header "Shell Setup"
run_command "chsh -s $(command -v bash) $USER_NAME" "Set Bash"

BASHRC_DEST="$USER_HOME/.bashrc"
sudo -u "$USER_NAME" bash -c "cat <<'EOF' > $BASHRC_DEST
# Pywal restoration
wal -R -q 2>/dev/null && clear
eval \"\$(starship init bash)\"
fastfetch
EOF"

# ----------------------------
# Config & Directories
# ----------------------------
print_header "Applying Configs"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts} "$WAL_TEMPLATES" "$WAL_CACHE"

# Clean Yazi state
sudo -u "$USER_NAME" rm -rf "$USER_HOME/.cache/yazi" "$USER_HOME/.local/state/yazi"

# Copy configs (if they exist in your repo)
[[ -f "$REPO_ROOT/configs/hypr/hyprland.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/hypr/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf"
[[ -f "$REPO_ROOT/configs/waybar/config" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/waybar/config" "$CONFIG_DIR/waybar/config"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"

# Kitty & Pywal templates
[[ -f "$REPO_ROOT/configs/kitty/kitty.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/kitty/kitty.conf" "$WAL_TEMPLATES/kitty.conf"
[[ -d "$REPO_ROOT/configs/wal/templates" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/wal/templates"/* "$WAL_TEMPLATES/"

# Symlinks (Crucial for Waybar/Kitty/Mako)
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# Wallpapers
[[ -d "$REPO_ROOT/Pictures/Wallpapers" ]] && sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures" && sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"

# ----------------------------
# Initialization (Fixed Waybar/UI issue)
# ----------------------------
print_header "Initializing Pywal"
# Find first wallpaper to generate the files that Waybar symlinks need
FIRST_WALL=$(find "$USER_HOME/Pictures/Wallpapers" -type f | head -n 1)
if [[ -n "$FIRST_WALL" ]]; then
    sudo -u "$USER_NAME" wal -i "$FIRST_WALL" -q
    print_success "✅ Initial colors generated"
else
    print_warning "No wallpapers found; Waybar/Mako colors will be missing until you run 'wal -i'."
fi

# ----------------------------
# Services (The SDDM Fix)
# ----------------------------
print_header "Finalizing Services"
systemctl enable --now bluetooth.service || true

if [ -f /usr/lib/systemd/system/sddm.service ]; then
    systemctl enable sddm.service
    print_success "✅ SDDM enabled"
else
    print_warning "SDDM not found. Trying one-tap install."
    pacman -S --noconfirm sddm
    systemctl enable sddm.service
fi

print_success "🎉 Done! Reboot and log in to Hyprland."
