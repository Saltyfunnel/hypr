#!/bin/bash
# Full Hyprland Installer – 2026 AMD + Pywal + Dotfiles
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
print_header "Updating system & installing AMD drivers"
run_command "pacman -Syyu --noconfirm" "System update"
run_command "pacman -S --noconfirm mesa vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu linux-headers" "Install AMD drivers"

# ----------------------------
# Core Packages
# ----------------------------
print_header "Installing core packages"
# Explicitly ensuring sddm is in the list
PACMAN_PACKAGES=(
    hyprland waybar swww mako grim slurp kitty nano wget jq btop
    sddm polkit-kde-agent-1 code curl bluez bluez-utils blueman python-pyqt6 python-pillow
    gvfs udiskie udisks2 firefox fastfetch starship mpv gnome-disk-utility pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2 trash-cli
    unzip p7zip tar gzip xz bzip2 unrar atool imv
    yazi ffmpegthumbnailer poppler imagemagick chafa
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono ttf-cascadia-code-nerd
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[@]}" "Install core packages"

# ----------------------------
# Install Yay & AUR packages
# ----------------------------
print_header "Installing Yay & AUR packages"
if ! command -v yay &>/dev/null; then
    run_command "pacman -S --noconfirm --needed git base-devel" "Install base-devel tools"
    run_command "rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay"
    run_command "(cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm)" "Install yay"
fi

run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "Install Pywal16"

# ----------------------------
# Shell Setup
# ----------------------------
print_header "Configuring shell"
run_command "chsh -s $(command -v bash) $USER_NAME" "Set Bash"

BASHRC_SRC="$REPO_ROOT/configs/.bashrc"
BASHRC_DEST="$USER_HOME/.bashrc"
if [[ -f "$BASHRC_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$BASHRC_SRC" "$BASHRC_DEST"
else
    sudo -u "$USER_NAME" bash -c "cat <<'EOF' > $BASHRC_DEST
wal -R -q 2>/dev/null && clear
eval \"\$(starship init bash)\"
fastfetch
EOF"
fi

# ----------------------------
# Config & Directories
# ----------------------------
print_header "Applying configs"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts} "$WAL_TEMPLATES" "$WAL_CACHE"

# Copy repo configs (logic remains same)
[[ -f "$REPO_ROOT/configs/hypr/hyprland.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/hypr/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf"
[[ -f "$REPO_ROOT/configs/waybar/config" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/waybar/config" "$CONFIG_DIR/waybar/config"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"

# Kitty & Pywal symlinks (logic remains same)
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# Scripts & permissions
[[ -d "$SCRIPTS_SRC" ]] && sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/* "$CONFIG_DIR/scripts/" && sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*

# ----------------------------
# Services Enablement (The Fix)
# ----------------------------
print_header "Enabling System Services"

# Enable Bluetooth
if systemctl list-unit-files | grep -q bluetooth.service; then
    run_command "systemctl enable --now bluetooth.service" "Enable Bluetooth"
else
    print_warning "Bluetooth service not found, skipping."
fi

# Enable SDDM
if [ -f /usr/lib/systemd/system/sddm.service ] || [ -f /etc/systemd/system/sddm.service ]; then
    run_command "systemctl enable sddm.service" "Enable SDDM"
else
    print_warning "sddm.service still not found. Attempting forced reinstall..."
    pacman -S --noconfirm sddm
    systemctl enable sddm.service || print_error "Failed to enable SDDM after reinstall."
fi

# ----------------------------
# Final message
# ----------------------------
print_success "🎉 Installation complete! Reboot to start Hyprland."
