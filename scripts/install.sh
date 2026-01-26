#!/bin/bash
# Minimal Hyprland Installer - 2026 Unified (AMD/Nvidia + UI Fixes)
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
}

# ----------------------------
# Setup Variables
# ----------------------------
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_SRC="$REPO_ROOT/scripts"
WAL_CACHE="$USER_HOME/.cache/wal"

[[ "$EUID" -eq 0 ]] || print_error "Run as root (sudo $0)"

# ----------------------------
# Drivers & Updates
# ----------------------------
print_header "System & Drivers"
run_command "pacman -Syu --noconfirm" "System update"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)
if echo "$GPU_INFO" | grep -qi nvidia; then
    run_command "pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" "NVIDIA"
elif echo "$GPU_INFO" | grep -qi amd; then
    run_command "pacman -S --noconfirm --needed xf86-video-amdgpu mesa vulkan-radeon lib32-vulkan-radeon linux-headers" "AMD"
fi

# ----------------------------
# Packages
# ----------------------------
print_header "Installing Apps"
APPS="hyprland waybar swww mako grim slurp kitty nano wget jq btop sddm code curl bluez bluez-utils blueman python-pyqt6 python-pillow gvfs udiskie udisks2 firefox fastfetch starship gnome-disk-utility pavucontrol yazi ffmpegthumbnailer poppler imagemagick chafa imv unzip p7zip tar gzip xz bzip2 unrar trash-cli git base-devel ttf-jetbrains-mono-nerd ttf-iosevka-nerd"

run_command "pacman -S --noconfirm --needed $APPS" "Core Apps"
pacman -S --noconfirm --needed polkit-kde-agent-1 || pacman -S --noconfirm --needed polkit-kde-agent || true

# ----------------------------
# AUR (Yay & Pywal)
# ----------------------------
print_header "AUR Tools"
if ! command -v yay &>/dev/null; then
    run_command "rm -rf /tmp/yay && sudo -u $USER_NAME git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone Yay"
    (cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm)
fi
run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "Pywal16"

# ----------------------------
# Config & Shell (UPDATED FIXES)
# ----------------------------
print_header "Configs & Visuals"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts,wal/templates} "$WAL_CACHE"

# UPDATED .bashrc logic (Fixes Deprecated Error + Fastfetch)
sudo -u "$USER_NAME" bash -c "cat <<'EOF' > $USER_HOME/.bashrc
# Restore Pywal Colors (The 2026 way)
[[ -f ~/.cache/wal/sequences ]] && cat ~/.cache/wal/sequences

# Starship Prompt
if command -v starship >/dev/null; then
    eval \"\$(starship init bash)\"
fi

# Fastfetch on launch
if command -v fastfetch >/dev/null; then
    fastfetch
fi

# Aliases
alias v='yazi'
alias ls='ls --color=auto'
EOF"

# Copy configs from Repo
[[ -f "$REPO_ROOT/configs/fastfetch/config.jsonc" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
[[ -f "$REPO_ROOT/configs/starship/starship.toml" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/starship/starship.toml" "$CONFIG_DIR/starship.toml"

# Symlinks
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# Scripts & Wallpapers
[[ -d "$SCRIPTS_SRC" ]] && sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/* "$CONFIG_DIR/scripts/"
[[ -d "$REPO_ROOT/Pictures/Wallpapers" ]] && sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures" && sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"
sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*

# ----------------------------
# Finalization
# ----------------------------
systemctl enable sddm.service || true
systemctl enable bluetooth.service || true
print_success "Install Done. Reboot now for a clean 2026 setup."
