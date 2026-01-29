#!/bin/bash
# Minimal Hyprland Installer - 2026 Optimized (Nvidia + Yazi + Plugins)
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
# System Update & Drivers (NVIDIA FIX)
# ----------------------------
print_header "Updating system & Fixing Drivers"
run_command "pacman -Syyu --noconfirm" "System update"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    run_command "pacman -S --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" "Install NVIDIA Open Drivers"
    
    # Enable Early KMS
    sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    run_command "mkinitcpio -P" "Rebuilding Initramfs"
    
    if [ -f /etc/default/grub ]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
        run_command "grub-mkconfig -o /boot/grub/grub.cfg" "Updating GRUB"
    fi
elif echo "$GPU_INFO" | grep -qi amd; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu mesa vulkan-radeon" "Install AMD drivers"
fi

# ----------------------------
# Core Packages
# ----------------------------
print_header "Installing core packages"
PACMAN_PACKAGES=(
    # Desktop Environment
    hyprland waybar swww mako grim slurp kitty nano wget jq btop
    sddm polkit polkit-kde-agent code curl bluez bluez-utils blueman python-pyqt6 python-pillow
    gvfs udiskie udisks2 firefox fastfetch starship mpv gnome-disk-utility pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2 trash-cli
    unzip p7zip tar gzip xz bzip2 unrar atool imv
    
    # Yazi & Image Preview Stack (ya comes with yazi)
    yazi ffmpegthumbnailer poppler imagemagick chafa
    
    # Fonts
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono ttf-cascadia-code-nerd
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Install core packages"

run_command "systemctl enable --now bluetooth.service" "Enable Bluetooth"

# ----------------------------
# Install Yay & AUR
# ----------------------------
print_header "Installing Yay"
if ! command -v yay &>/dev/null; then
    run_command "pacman -S --noconfirm --needed git base-devel" "Base tools"
    run_command "rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone Yay"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay && cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Install Yay"
fi

run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "AUR Packages"

# ----------------------------
# Shell Setup
# ----------------------------
print_header "Shell Setup"
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
print_header "Applying Configs"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts} "$WAL_TEMPLATES" "$WAL_CACHE"

# Clean old Yazi state
sudo -u "$USER_NAME" rm -rf "$USER_HOME/.cache/yazi" "$USER_HOME/.local/state/yazi"

# Copy configs
[[ -f "$REPO_ROOT/configs/hypr/hyprland.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/hypr/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf"
[[ -f "$REPO_ROOT/configs/waybar/config" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/waybar/config" "$CONFIG_DIR/waybar/config"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"
[[ -f "$REPO_ROOT/configs/fastfetch/config.jsonc" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
[[ -f "$REPO_ROOT/configs/starship/starship.toml" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/starship/starship.toml" "$CONFIG_DIR/starship.toml"
[[ -f "$REPO_ROOT/configs/btop/btop.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/btop/btop.conf" "$CONFIG_DIR/btop/btop.conf"

# Kitty & Pywal
[[ -f "$REPO_ROOT/configs/kitty/kitty.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/kitty/kitty.conf" "$WAL_TEMPLATES/kitty.conf"
[[ -d "$REPO_ROOT/configs/wal/templates" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/wal/templates"/* "$WAL_TEMPLATES/"

# Symlinks
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# Scripts & Permissions
[[ -d "$SCRIPTS_SRC" ]] && sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/* "$CONFIG_DIR/scripts/" && sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*

# Wallpapers
[[ -d "$REPO_ROOT/Pictures/Wallpapers" ]] && sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures" && sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"

# ----------------------------
# Yazi Configuration (Clean Copy)
# ----------------------------
print_header "Applying Yazi Configs"

# 1. Kill any existing state that causes the input hang
sudo -u "$USER_NAME" rm -rf "$USER_HOME/.cache/yazi" "$USER_HOME/.local/state/yazi"

# 2. Ensure directory exists
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/yazi"

# 3. Copy your repo configs exactly
if [[ -d "$REPO_ROOT/configs/yazi" ]]; then
    sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"
    print_success "✅ Yazi configs applied from repo"
fi

# 4. Final Permissions Check
run_command "chown -R $USER_NAME:$USER_NAME $CONFIG_DIR/yazi" "Fixing Yazi Permissions"

# ----------------------------
# Finalization
# ----------------------------
systemctl enable sddm.service
print_success "Done. Reboot now."
