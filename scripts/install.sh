
#!/bin/bash
# Minimal Hyprland Installer with PROPER pywal16 template support
# Updated for Jan 2026 NVIDIA Driver Changes (590+ / Legacy Support)
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
command -v systemctl &>/dev/null || print_error "systemctl not found"
print_success "✅ Environment checks passed"

# ----------------------------
# System Update & Kernel Headers (CRITICAL FOR NVIDIA)
# ----------------------------
print_header "Updating system and detecting kernel"
run_command "pacman -Syyu --noconfirm" "System update"

KERNEL_TYPE=$(uname -r)
if [[ "$KERNEL_TYPE" == *"lts"* ]]; then
    run_command "pacman -S --noconfirm --needed linux-lts-headers" "LTS Headers"
elif [[ "$KERNEL_TYPE" == *"zen"* ]]; then
    run_command "pacman -S --noconfirm --needed linux-zen-headers" "Zen Headers"
else
    run_command "pacman -S --noconfirm --needed linux-headers" "Standard Headers"
fi

# ----------------------------
# GPU Drivers (The 2026 NVIDIA Fix)
# ----------------------------
print_header "Detecting GPU"
GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)
INSTALL_NVIDIA_LEGACY=false

if echo "$GPU_INFO" | grep -qi nvidia; then
    CARD_MODEL=$(lspci | grep -i nvidia | grep -Ei "GTX|RTX|Quadro" || true)
    
    # Check for Pascal (10xx), Maxwell (900), or older
    if echo "$CARD_MODEL" | grep -qiE "GTX (4|5|6|7|9|10)"; then
        print_warning "Legacy GPU detected. Will install via AUR (Step 2)."
        INSTALL_NVIDIA_LEGACY=true
    else
        run_command "pacman -S --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver" "Modern NVIDIA Drivers"
    fi

    # Enable KMS
    sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    run_command "mkinitcpio -P" "Rebuilding Initramfs"

    # Update GRUB if present
    if [ -f /etc/default/grub ]; then
        if ! grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
            run_command "grub-mkconfig -o /boot/grub/grub.cfg" "Updating GRUB"
        fi
    fi
elif echo "$GPU_INFO" | grep -qi amd; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu mesa vulkan-radeon" "AMD drivers"
fi

# ----------------------------
# Core Packages
# ----------------------------
print_header "Installing core packages"
PACMAN_PACKAGES=(
    hyprland waybar swww mako grim slurp kitty nano wget jq btop
    sddm polkit-kde-agent curl bluez bluez-utils blueman python-pyqt6 python-pillow
    gvfs udiskie udisks2 chafa firefox yazi fastfetch starship mpv pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2 trash-cli
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Install core packages"

# Enable essential services
run_command "systemctl enable --now bluetooth.service" "Enable Bluetooth"

# ----------------------------
# Install Yay & Legacy Drivers
# ----------------------------
print_header "Installing Yay & AUR Packages"
if ! command -v yay &>/dev/null; then
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git + base-devel"
    run_command "rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay && cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Install yay"
fi

if [ "$INSTALL_NVIDIA_LEGACY" = true ]; then
    run_command "sudo -u $USER_NAME yay -S --noconfirm nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils" "Legacy NVIDIA"
fi

run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16 localsend-bin" "AUR extras"

# ----------------------------
# Setup Directory Structure
# ----------------------------
print_header "Creating config directories"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts,btop}
sudo -u "$USER_NAME" mkdir -p "$WAL_TEMPLATES" "$WAL_CACHE" "$USER_HOME/Pictures/Screenshots"

# ----------------------------
# Copy Static Configs
# ----------------------------
print_header "Copying static configuration files"

[[ -f "$REPO_ROOT/configs/hypr/hyprland.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/hypr/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf"
[[ -f "$REPO_ROOT/configs/waybar/config" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/waybar/config" "$CONFIG_DIR/waybar/config"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"
[[ -f "$REPO_ROOT/configs/fastfetch/config.jsonc" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
[[ -f "$REPO_ROOT/configs/starship/starship.toml" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/starship/starship.toml" "$CONFIG_DIR/starship.toml"
[[ -f "$REPO_ROOT/configs/btop/btop.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/btop/btop.conf" "$CONFIG_DIR/btop/btop.conf"

# ----------------------------
# Copy Pywal Templates
# ----------------------------
print_header "Copying Pywal templates"
[[ -f "$REPO_ROOT/configs/kitty/kitty.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/kitty/kitty.conf" "$WAL_TEMPLATES/kitty.conf"
[[ -d "$REPO_ROOT/configs/wal/templates" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/wal/templates"/* "$WAL_TEMPLATES/"

# ----------------------------
# Create Symlinks to Pywal Cache
# ----------------------------
print_header "Creating symlinks"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# ----------------------------
# Copy Scripts & Wallpapers
# ----------------------------
if [[ -d "$SCRIPTS_SRC" ]]; then
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/*.{sh,py} "$CONFIG_DIR/scripts/" 2>/dev/null || true
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*
fi

if [[ -d "$REPO_ROOT/Pictures/Wallpapers" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures"
    sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"
fi

# ----------------------------
# Enable SDDM
# ----------------------------
systemctl enable sddm.service
print_success "\n✅ Installation complete! Please reboot."
