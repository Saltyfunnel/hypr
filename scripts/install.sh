#!/bin/bash
# Minimal Hyprland Installer - 2026 Optimized (Universal GPU + UI Stack)
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
# System Update & Drivers
# ----------------------------
print_header "Updating system & Drivers"
run_command "pacman -Syyu --noconfirm" "System update"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    run_command "pacman -S --noconfirm nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" "NVIDIA Drivers"
    sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    run_command "mkinitcpio -P" "Rebuilding Initramfs"
elif echo "$GPU_INFO" | grep -qi amd; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu mesa vulkan-radeon lib32-vulkan-radeon" "AMD Drivers"
fi

# ----------------------------
# Core Packages
# ----------------------------
print_header "Installing UI & Tool Stack"
PACMAN_PACKAGES=(
    hyprland waybar swww mako grim slurp kitty nano wget jq btop
    sddm polkit-kde-agent-1 code curl bluez bluez-utils blueman python-pyqt6 python-pillow
    gvfs udiskie udisks2 firefox fastfetch starship gnome-disk-utility pavucontrol
    unzip p7zip tar gzip xz bzip2 unrar imv
    yazi ffmpegthumbnailer poppler imagemagick chafa
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-cascadia-code-nerd
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Install packages"

# ----------------------------
# AUR Setup
# ----------------------------
if ! command -v yay &>/dev/null; then
    run_command "rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone Yay"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay && cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Install Yay"
fi
run_command "sudo -u $USER_NAME yay -S --noconfirm python-pywal16" "Install Pywal16"

# ----------------------------
# Fastfetch / Starship / Bash Setup
# ----------------------------
print_header "Setting up Shell Visuals"
BASHRC_DEST="$USER_HOME/.bashrc"

# Create a clean .bashrc that initializes everything correctly
sudo -u "$USER_NAME" bash -c "cat <<'EOF' > $BASHRC_DEST
# Pywal Color Restore
(wal -r -q &)

# Starship Prompt
eval \"\$(starship init bash)\"

# Fastfetch on Startup
if [[ -z \$DISPLAY_FETCHED ]]; then
    fastfetch
    export DISPLAY_FETCHED=1
fi

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias v='yazi'
EOF"

# ----------------------------
# Config & Directories
# ----------------------------
print_header "Applying Configs"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts,wal/templates} "$WAL_CACHE"

# Mako Setup (Pywal compatible)
if [[ -f "$REPO_ROOT/configs/mako/config" ]]; then
    sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/mako/config" "$WAL_TEMPLATES/mako-config"
else
    # Create default Mako template for Pywal if missing
    sudo -u "$USER_NAME" bash -c "cat <<'EOF' > $WAL_TEMPLATES/mako-config
background-color={background}
text-color={foreground}
border-color={color4}
border-size=2
border-radius=10
font=JetBrainsMono Nerd Font 10
EOF"
fi

# Copy Fastfetch & Starship Configs
[[ -f "$REPO_ROOT/configs/fastfetch/config.jsonc" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
[[ -f "$REPO_ROOT/configs/starship/starship.toml" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/starship/starship.toml" "$CONFIG_DIR/starship.toml"

# Symlinks for the Live-Theme switch
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"

# Scripts
[[ -d "$SCRIPTS_SRC" ]] && sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/* "$CONFIG_DIR/scripts/" && sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*

# ----------------------------
# Finalization
# ----------------------------
systemctl enable sddm.service
systemctl enable bluetooth.service
print_success "Done. Fastfetch, Starship, and Mako are configured. Reboot now."
