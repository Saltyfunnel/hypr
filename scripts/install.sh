#!/bin/bash
# Minimal Hyprland Installer - 2026 Optimized
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
# GPU Driver Detection
# ----------------------------
print_header "Detecting GPU & Updating System"
run_command "pacman -Syu --noconfirm" "System update"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)
if echo "$GPU_INFO" | grep -qi nvidia; then
    run_command "pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" "NVIDIA Drivers"
elif echo "$GPU_INFO" | grep -qi amd; then
    run_command "pacman -S --noconfirm --needed xf86-video-amdgpu mesa vulkan-radeon lib32-vulkan-radeon linux-headers" "AMD Drivers"
fi

# ----------------------------
# The Clean Package List
# ----------------------------
print_header "Installing Core Packages"

# Separated for reliability
CORE_APPS="hyprland waybar swww mako grim slurp kitty nano wget jq btop sddm code curl bluez bluez-utils blueman python-pyqt6 python-pillow gvfs udiskie udisks2 firefox fastfetch starship gnome-disk-utility pavucontrol"
PREVIEW_STACK="yazi ffmpegthumbnailer poppler imagemagick chafa imv"
UTILS="unzip p7zip tar gzip xz bzip2 unrar trash-cli git base-devel"
FONTS="ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-cascadia-code-nerd ttf-fira-code"

# Install in chunks to avoid single-package failure stopping the whole script
run_command "pacman -S --noconfirm --needed $CORE_APPS" "Installing Main Apps"
run_command "pacman -S --noconfirm --needed $PREVIEW_STACK" "Installing Yazi Stack"
run_command "pacman -S --noconfirm --needed $UTILS" "Installing Utilities"
run_command "pacman -S --noconfirm --needed $FONTS" "Installing Fonts"

# Polkit Handling (Package name varies)
pacman -S --noconfirm --needed polkit-kde-agent-1 || pacman -S --noconfirm --needed polkit-kde-agent || print_warning "Polkit agent not found"

# ----------------------------
# AUR & Pywal
# ----------------------------
print_header "Installing Yay & Pywal"
if ! command -v yay &>/dev/null; then
    run_command "rm -rf /tmp/yay && sudo -u $USER_NAME git clone https://aur.archlinux.org/yay.git /tmp/yay" "Cloning Yay"
    (cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm)
fi
run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "Pywal16"

# ----------------------------
# Fastfetch / Starship / Bash Setup
# ----------------------------
print_header "Applying Shell Config"
BASHRC_DEST="$USER_HOME/.bashrc"
sudo -u "$USER_NAME" bash -c "cat <<'EOF' > $BASHRC_DEST
# Auto-restore Pywal colors
(wal -r -q &)
# Starship
eval \"\$(starship init bash)\"
# Fastfetch (once per session)
if [[ -z \$DISPLAY_FETCHED ]]; then
    fastfetch
    export DISPLAY_FETCHED=1
fi
alias v='yazi'
EOF"

# ----------------------------
# Config & Directories
# ----------------------------
print_header "Applying Config Files"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts,wal/templates} "$WAL_CACHE"

# Copy Mako Template
if [[ -f "$REPO_ROOT/configs/mako/config" ]]; then
    sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/mako/config" "$WAL_TEMPLATES/mako-config"
fi

# Copy Fastfetch & Starship
[[ -f "$REPO_ROOT/configs/fastfetch/config.jsonc" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
[[ -f "$REPO_ROOT/configs/starship/starship.toml" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/starship/starship.toml" "$CONFIG_DIR/starship.toml"

# Kitty Template
[[ -f "$REPO_ROOT/configs/kitty/kitty.conf" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/kitty/kitty.conf" "$WAL_TEMPLATES/kitty.conf"

# Symlinks
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"

# Scripts
[[ -d "$SCRIPTS_SRC" ]] && sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/* "$CONFIG_DIR/scripts/" && sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*

# ----------------------------
# Finalization
# ----------------------------
systemctl enable sddm.service || true
systemctl enable bluetooth.service || true
print_success "Installer Complete. Reboot to apply changes."
