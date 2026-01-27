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
CONFIGS_SRC="$REPO_ROOT/configs"
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
APPS="hyprland waybar swww mako grim slurp kitty nano wget jq btop sddm code curl bluez bluez-utils blueman python-pyqt6 python-pillow gvfs udiskie udisks2 firefox fastfetch starship gnome-disk-utility pavucontrol yazi ffmpegthumbnailer poppler imagemagick chafa imv unzip p7zip tar gzip xz bzip2 unrar trash-cli git base-devel ttf-jetbrains-mono-nerd ttf-iosevka-nerd wl-clipboard xdg-desktop-portal-hyprland qt5-wayland qt6-wayland"

run_command "pacman -S --noconfirm --needed $APPS" "Core Apps"
pacman -S --noconfirm --needed polkit-kde-agent || pacman -S --noconfirm --needed polkit-gnome || true

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
# Config & Shell
# ----------------------------
print_header "Configs & Visuals"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts,wal/templates} "$WAL_CACHE"

# CRITICAL FIX: Remove old dangling symlinks first
print_header "Cleaning Old Symlinks"
sudo -u "$USER_NAME" rm -f "$CONFIG_DIR/mako/config" 2>/dev/null || true
sudo -u "$USER_NAME" rm -f "$CONFIG_DIR/waybar/style.css" 2>/dev/null || true
sudo -u "$USER_NAME" rm -f "$CONFIG_DIR/kitty/kitty.conf" 2>/dev/null || true
sudo -u "$USER_NAME" rm -f "$CONFIG_DIR/hypr/colors-hyprland.conf" 2>/dev/null || true
print_success "Old symlinks removed"

# CRITICAL FIX: Copy ALL Hyprland configs (not just colors)
if [[ -d "$CONFIGS_SRC/hypr" ]]; then
    print_header "Copying Hyprland Configuration"
    sudo -u "$USER_NAME" cp -rf "$CONFIGS_SRC/hypr/"* "$CONFIG_DIR/hypr/" 2>/dev/null || true
    print_success "Hyprland config copied"
fi

# Copy Waybar configs (both config.jsonc and style.css)
if [[ -d "$CONFIGS_SRC/waybar" ]]; then
    sudo -u "$USER_NAME" cp -rf "$CONFIGS_SRC/waybar/"* "$CONFIG_DIR/waybar/" 2>/dev/null || true
    print_success "Waybar config copied"
fi

# Copy Kitty base config (with fallback colors)
if [[ -f "$CONFIGS_SRC/kitty/kitty.conf" ]]; then
    sudo -u "$USER_NAME" cp "$CONFIGS_SRC/kitty/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
else
    # Create a default kitty.conf that includes pywal colors
    sudo -u "$USER_NAME" cat > "$CONFIG_DIR/kitty/kitty.conf" << 'KITTYCONF'
# Kitty Configuration
font_family      JetBrainsMono Nerd Font
font_size        11.0
window_padding_width 8
confirm_os_window_close 0
enable_audio_bell no
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
repaint_delay 10
input_delay 3
sync_to_monitor yes

# Include pywal colors (generated from template)
include ~/.cache/wal/kitty-wal.conf

# Fallback colors
background #1a1b26
foreground #c0caf5
KITTYCONF
fi

# Copy Pywal template for kitty (kitty-wal.conf)
if [[ -f "$CONFIGS_SRC/wal/templates/kitty-wal.conf" ]]; then
    sudo -u "$USER_NAME" cp "$CONFIGS_SRC/wal/templates/kitty-wal.conf" "$CONFIG_DIR/wal/templates/kitty-wal.conf"
fi

# Copy Mako config
if [[ -f "$CONFIGS_SRC/mako/config" ]]; then
    sudo -u "$USER_NAME" cp "$CONFIGS_SRC/mako/config" "$CONFIG_DIR/mako/config"
fi

# Copy Yazi config
if [[ -d "$CONFIGS_SRC/yazi" ]]; then
    sudo -u "$USER_NAME" cp -rf "$CONFIGS_SRC/yazi/"* "$CONFIG_DIR/yazi/" 2>/dev/null || true
fi

# Copy Fastfetch
[[ -f "$CONFIGS_SRC/fastfetch/config.jsonc" ]] && sudo -u "$USER_NAME" cp "$CONFIGS_SRC/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"

# Copy Starship
[[ -f "$CONFIGS_SRC/starship/starship.toml" ]] && sudo -u "$USER_NAME" cp "$CONFIGS_SRC/starship/starship.toml" "$CONFIG_DIR/starship.toml"

# Copy Pywal templates
if [[ -d "$CONFIGS_SRC/wal/templates" ]]; then
    sudo -u "$USER_NAME" cp -rf "$CONFIGS_SRC/wal/templates/"* "$CONFIG_DIR/wal/templates/" 2>/dev/null || true
fi

# ----------------------------
# GPU Environment Config
# ----------------------------
print_header "Generating GPU Environment Config"

GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.conf"
GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

sudo -u "$USER_NAME" bash -c "cat > $GPU_ENV_FILE" << 'GPUEOF'
# Auto-generated GPU environment variables
# Generated during installation

GPUEOF

if echo "$GPU_INFO" | grep -qi nvidia; then
    print_success "Detected NVIDIA GPU - configuring environment"
    sudo -u "$USER_NAME" bash -c "cat >> $GPU_ENV_FILE" << 'NVIDIAEOF'
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
env = __GL_GSYNC_ALLOWED,1
env = __GL_VRR_ALLOWED,1
env = QT_QPA_PLATFORM,wayland
NVIDIAEOF
elif echo "$GPU_INFO" | grep -qi amd; then
    print_success "Detected AMD GPU - configuring environment"
    sudo -u "$USER_NAME" bash -c "cat >> $GPU_ENV_FILE" << 'AMDEOF'
env = LIBVA_DRIVER_NAME,radeonsi
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
AMDEOF
elif echo "$GPU_INFO" | grep -qi intel; then
    print_success "Detected Intel GPU - configuring environment"
    sudo -u "$USER_NAME" bash -c "cat >> $GPU_ENV_FILE" << 'INTELEOF'
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
INTELEOF
else
    print_success "No GPU detected - using default Wayland environment"
    sudo -u "$USER_NAME" bash -c "cat >> $GPU_ENV_FILE" << 'DEFAULTEOF'
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
DEFAULTEOF
fi

print_success "GPU environment config created: $GPU_ENV_FILE"

# Scripts & Wallpapers
if [[ -d "$SCRIPTS_SRC" ]]; then
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC/"* "$CONFIG_DIR/scripts/"
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"* 2>/dev/null || true
    print_success "Scripts copied and made executable"
fi

if [[ -d "$REPO_ROOT/Pictures/Wallpapers" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures"
    sudo -u "$USER_NAME" cp -rf "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"
    print_success "Wallpapers copied"
fi

# GENERATE GPU-SPECIFIC ENVIRONMENT
print_header "Generating GPU Environment"
sudo -u "$USER_NAME" bash -c "cat > $CONFIG_DIR/scripts/generate-gpu-env.sh" << 'GPUSCRIPT'
#!/bin/bash
OUTPUT_FILE="$HOME/.config/hypr/gpu-env.conf"
GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)
echo "# Auto-generated GPU environment variables" > "$OUTPUT_FILE"
echo "# Generated on: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

if echo "$GPU_INFO" | grep -qi nvidia; then
    cat >> "$OUTPUT_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
env = __GL_GSYNC_ALLOWED,1
env = __GL_VRR_ALLOWED,1
env = QT_QPA_PLATFORM,wayland
cursor { no_hardware_cursors = true }
EOF
elif echo "$GPU_INFO" | grep -qi amd; then
    cat >> "$OUTPUT_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,radeonsi
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
EOF
elif echo "$GPU_INFO" | grep -qi intel; then
    cat >> "$OUTPUT_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
EOF
fi
GPUSCRIPT

sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/generate-gpu-env.sh"
sudo -u "$USER_NAME" bash "$CONFIG_DIR/scripts/generate-gpu-env.sh"
print_success "GPU environment generated"

# .bashrc setup
sudo -u "$USER_NAME" bash -c "cat <<'EOF' > $USER_HOME/.bashrc
# Restore Pywal Colors
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

# CRITICAL: Create symlinks AFTER copying base configs
# Only symlink if Pywal templates exist
if [[ -f "$CONFIG_DIR/wal/templates/mako-config" ]]; then
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
fi

if [[ -f "$CONFIG_DIR/wal/templates/waybar-style.css" ]]; then
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
fi

# NOTE: Kitty uses "include" directive, not symlink
# Pywal will generate ~/.cache/wal/kitty.conf
# Add to your kitty.conf: include ~/.cache/wal/kitty.conf

if [[ -f "$CONFIG_DIR/wal/templates/colors-hyprland.conf" ]]; then
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"
fi

# ----------------------------
# Finalization
# ----------------------------
print_header "Enabling Services"
systemctl enable sddm.service || true
systemctl enable bluetooth.service || true

# Set ownership
chown -R "$USER_NAME:$USER_NAME" "$USER_HOME/.config" "$USER_HOME/.cache"

print_success "✓ Install Complete!"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "1. Reboot your system"
echo "2. Login to Hyprland via SDDM"
echo "3. Press SUPER+Q to open a terminal (Kitty)"
echo "4. Run: wal -i ~/Pictures/Wallpapers/<your-wallpaper.jpg>"
echo "   This will generate themes and start waybar/mako"
echo ""
echo "Common keybinds (check ~/.config/hypr/hyprland.conf):"
echo "  SUPER+Q = Terminal"
echo "  SUPER+C = Close window"
echo "  SUPER+M = Exit"
echo "  SUPER+E = File manager"
echo "  SUPER+V = Toggle floating"
echo "  SUPER+R = App launcher (wofi/rofi if installed)"
echo ""
