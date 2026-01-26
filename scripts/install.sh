#!/bin/bash
# Hyprland Installer – 2026 AMD/NVIDIA + Pywal + Dotfiles (Production-ready)
set -euo pipefail

# ----------------------------
# Helper functions
# ----------------------------
print_header() { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success() { echo -e "\e[32m$1\e[0m"; }
print_warning() { echo -e "\e[33mWarning: $1\e[0m" >&2; }
print_error() { echo -e "\e[31mError: $1\e[0m"; exit 1; }

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
HYPR_CONFIG="$CONFIG_DIR/hypr"
GPU_CONF="$HYPR_CONFIG/gpu.conf"

# ----------------------------
# Checks
# ----------------------------
[[ "$EUID" -eq 0 ]] || print_error "Run as root (sudo $0)"
command -v pacman &>/dev/null || print_error "pacman not found"

# ----------------------------
# System Update & GPU Drivers
# ----------------------------
print_header "Updating system & installing GPU drivers"
run_command "pacman -Syyu --noconfirm" "System update"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    print_header "Detected NVIDIA GPU"
    run_command "pacman -S --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" "Install NVIDIA drivers"

    sudo -u "$USER_NAME" mkdir -p "$HYPR_CONFIG"
    cat <<EOF | sudo -u "$USER_NAME" tee "$GPU_CONF" >/dev/null
# NVIDIA GPU – auto-generated
env = LIBVA_DRIVER_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
env = WLR_NO_HARDWARE_CURSORS,1
env = WLR_RENDERER,vulkan
EOF

elif echo "$GPU_INFO" | grep -qi amd; then
    print_header "Detected AMD GPU"
    run_command "pacman -S --noconfirm mesa vulkan-radeon lib32-vulkan-radeon" "Install AMD drivers"

    sudo -u "$USER_NAME" mkdir -p "$HYPR_CONFIG"
    cat <<EOF | sudo -u "$USER_NAME" tee "$GPU_CONF" >/dev/null
# AMD GPU – auto-generated
env = WLR_RENDERER,vulkan
EOF

else
    print_warning "Unknown GPU, using generic GPU.conf"
    sudo -u "$USER_NAME" mkdir -p "$HYPR_CONFIG"
    cp "$REPO_ROOT/configs/hypr/gpu.conf" "$GPU_CONF"
fi

# ----------------------------
# Core Packages (without SDDM)
# ----------------------------
print_header "Installing core packages"
PACMAN_PACKAGES=(
    hyprland waybar swww mako grim slurp kitty nano wget jq btop
    polkit polkit-kde-agent-1 code curl bluez bluez-utils blueman python-pyqt6 python-pillow
    gvfs udiskie udisks2 firefox fastfetch starship mpv gnome-disk-utility pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2 trash-cli
    unzip p7zip tar gzip xz bzip2 unrar atool imv
    yazi ffmpegthumbnailer poppler imagemagick chafa
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono ttf-cascadia-code-nerd
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[@]}" "Install core packages"

# ----------------------------
# Install SDDM explicitly & enable
# ----------------------------
run_command "pacman -S --noconfirm --needed sddm" "Install SDDM"
run_command "systemctl enable --now bluetooth.service" "Enable Bluetooth"
run_command "systemctl enable --now sddm.service" "Enable SDDM"

# ----------------------------
# Install Yay & AUR packages
# ----------------------------
print_header "Installing Yay & AUR packages"
if ! command -v yay &>/dev/null; then
    run_command "pacman -S --noconfirm --needed git base-devel" "Install base-devel tools"
    run_command "rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay"
    run_command "(cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm)" "Install yay"
fi

run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "Install Pywal16 from AUR"

# ----------------------------
# Shell Setup
# ----------------------------
print_header "Configuring shell"
run_command "chsh -s $(command -v bash) $USER_NAME" "Set Bash as default shell"

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
sudo -u "$USER_NAME" mkdir -p \
    "$HYPR_CONFIG" \
    "$CONFIG_DIR"/{waybar,kitty,yazi,fastfetch,mako,scripts} \
    "$WAL_TEMPLATES" "$WAL_CACHE"

# Clean old Yazi state
sudo -u "$USER_NAME" rm -rf "$USER_HOME/.cache/yazi" "$USER_HOME/.local/state/yazi"

# Copy repo configs
[[ -f "$REPO_ROOT/configs/hypr/hyprland.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/hypr/hyprland.conf" "$HYPR_CONFIG/hyprland.conf"
[[ -f "$REPO_ROOT/configs/waybar/config" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/waybar/config" "$CONFIG_DIR/waybar/config"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"
[[ -f "$REPO_ROOT/configs/fastfetch/config.jsonc" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
[[ -f "$REPO_ROOT/configs/starship/starship.toml" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/starship/starship.toml" "$CONFIG_DIR/starship.toml"
[[ -f "$REPO_ROOT/configs/btop/btop.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/btop/btop.conf" "$CONFIG_DIR/btop/btop.conf"

# Kitty & Pywal
[[ -f "$REPO_ROOT/configs/kitty/kitty.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/kitty/kitty.conf" "$WAL_TEMPLATES/kitty.conf"
[[ -d "$REPO_ROOT/configs/wal/templates" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/wal/templates"/* "$WAL_TEMPLATES/"

# Symlinks for Pywal (ensure dirs exist first)
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{waybar,mako,kitty,hypr}
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$HYPR_CONFIG/colors-hyprland.conf"

# Scripts & permissions
[[ -d "$SCRIPTS_SRC" ]] && sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/* "$CONFIG_DIR/scripts/" && sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*

# Wallpapers
[[ -d "$REPO_ROOT/Pictures/Wallpapers" ]] && sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures" && sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"

# ----------------------------
# Yazi Config
# ----------------------------
print_header "Applying Yazi configs"
sudo -u "$USER_NAME" rm -rf "$USER_HOME/.cache/yazi" "$USER_HOME/.local/state/yazi"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/yazi"
[[ -d "$REPO_ROOT/configs/yazi" ]] && sudo -u "$USER_NAME" cp -r "$REPO_ROOT/configs/yazi"/* "$CONFIG_DIR/yazi/"
run_command "chown -R $USER_NAME:$USER_NAME $CONFIG_DIR/yazi" "Fixing Yazi permissions"

# ----------------------------
# Final message
# ----------------------------
print_success "🎉 Installation complete! Reboot to start Hyprland."
