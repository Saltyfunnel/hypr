#!/bin/bash
# Minimal Hyprland Installer with PROPER pywal16 template support
# This version only copies static configs and templates - no redundant files!
set -euo pipefail

# ----------------------------
# Helper functions
# ----------------------------
print_header() {
    echo -e "\n--- \e[1m\e[34m$1\e[0m ---"
}

print_success() {
    echo -e "\e[32m$1\e[0m"
}

print_warning() {
    echo -e "\e[33mWarning: $1\e[0m" >&2
}

print_error() {
    echo -e "\e[31mError: $1\e[0m" >&2
    exit 1
}

run_command() {
    local cmd="$1"
    local desc="$2"
    echo -e "\nRunning: $desc"
    if ! eval "$cmd"; then
        print_error "Failed: $desc"
    fi
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

# Pywal template directories
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
# System Update
# ----------------------------
print_header "Updating system"
run_command "pacman -Syyu --noconfirm" "System update"

# ----------------------------
# GPU Drivers
# ----------------------------
print_header "Detecting GPU"
GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    run_command "pacman -S --noconfirm nvidia nvidia-utils" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi amd; then
    run_command "pacman -S --noconfirm xf86-video-amdgpu mesa vulkan-radeon" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi intel; then
    run_command "pacman -S --noconfirm mesa vulkan-intel" "Install Intel drivers"
else
    print_warning "No supported GPU detected. Skipping driver installation."
fi

# ----------------------------
# Core Packages
# ----------------------------
print_header "Installing core packages"
PACMAN_PACKAGES=(
    hyprland waybar swww mako grim slurp kitty nano wget jq oculante btop steam
    sddm polkit polkit-kde-agent code curl bluez bluez-utils blueman python-pyqt6 python-pillow
    udisks2 chafa firefox yazi fastfetch starship mpv gnome-disk-utility pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono ttf-cascadia-code-nerd
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Install core packages"

# Enable essential services
run_command "systemctl enable --now polkit.service" "Enable polkit"
run_command "systemctl enable --now bluetooth.service" "Enable Bluetooth service"

# ----------------------------
# Install Yay (AUR Helper)
# ----------------------------
print_header "Installing Yay"
if command -v yay &>/dev/null; then
    print_success "Yay already installed"
else
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git + base-devel"
    run_command "rm -rf /tmp/yay" "Remove old yay folder"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Set permissions for yay build"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay"
    run_command "rm -rf /tmp/yay" "Clean up temporary yay files"
fi

# ----------------------------
# Install AUR Packages
# ----------------------------
print_header "Installing AUR packages"
AUR_PACKAGES=(
    python-pywal16
    localsend-bin
    protonplus
)
for pkg in "${AUR_PACKAGES[@]}"; do
    if yay -Qs "^$pkg$" &>/dev/null; then
        print_success "✅ $pkg is already installed"
    else
        run_command "sudo -u $USER_NAME yay -S --noconfirm $pkg" "Install $pkg from AUR"
    fi
done

# ----------------------------
# Shell Setup (Bash)
# ----------------------------
print_header "Shell Setup"
run_command "chsh -s $(command -v bash) $USER_NAME" "Set Bash as default shell"

BASHRC_SRC="$REPO_ROOT/configs/.bashrc"
BASHRC_DEST="$USER_HOME/.bashrc"

if [[ -f "$BASHRC_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$BASHRC_SRC" "$BASHRC_DEST"
    print_success ".bashrc copied from repo"
else
    print_warning "No .bashrc found in repo, creating a minimal one"
    cat <<'EOF' | sudo -u "$USER_NAME" tee "$BASHRC_DEST" >/dev/null
# Restore Pywal colors and clear terminal
wal -R -q 2>/dev/null && clear

# Initialize Starship prompt
eval "$(starship init bash)"

# Run fastfetch after login
fastfetch
EOF
    print_success "Minimal .bashrc created with wal + fastfetch + starship"
fi

# ----------------------------
# Setup Directory Structure
# ----------------------------
print_header "Creating config directories"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts}
sudo -u "$USER_NAME" mkdir -p "$WAL_TEMPLATES"
sudo -u "$USER_NAME" mkdir -p "$WAL_CACHE"
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures/Screenshots"
print_success "Directory structure created"

# ----------------------------
# Copy Static Configs (no colors!)
# ----------------------------
print_header "Copying static configuration files"

# Hyprland main config (keybinds, window rules, etc)
HYPR_CONFIG_SRC="$REPO_ROOT/configs/hypr/hyprland.conf"
if [[ -f "$HYPR_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$HYPR_CONFIG_SRC" "$CONFIG_DIR/hypr/hyprland.conf"
    print_success "✅ Copied hyprland.conf"
fi

# Waybar config (modules and layout only, no colors)
WAYBAR_CONFIG_SRC="$REPO_ROOT/configs/waybar/config"
if [[ -f "$WAYBAR_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$WAYBAR_CONFIG_SRC" "$CONFIG_DIR/waybar/config"
    print_success "✅ Copied waybar/config"
fi

# Yazi configs (all 3 files)
for file in yazi.toml keybind.toml theme.toml; do
    SRC="$REPO_ROOT/configs/yazi/$file"
    if [[ -f "$SRC" ]]; then
        sudo -u "$USER_NAME" cp "$SRC" "$CONFIG_DIR/yazi/$file"
        print_success "✅ Copied yazi/$file"
    fi
done

# Fastfetch config
FASTFETCH_SRC="$REPO_ROOT/configs/fastfetch/config.jsonc"
if [[ -f "$FASTFETCH_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$FASTFETCH_SRC" "$CONFIG_DIR/fastfetch/config.jsonc"
    print_success "✅ Copied fastfetch/config.jsonc"
fi

# Starship config
STARSHIP_SRC="$REPO_ROOT/configs/starship/starship.toml"
if [[ -f "$STARSHIP_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$STARSHIP_SRC" "$CONFIG_DIR/starship.toml"
    print_success "✅ Copied starship.toml"
fi

# ----------------------------
# Copy Pywal Templates
# ----------------------------
print_header "Copying Pywal templates"

# Copy ALL templates from repo
TEMPLATE_SOURCE="$REPO_ROOT/configs/wal/templates"
if [[ -d "$TEMPLATE_SOURCE" ]]; then
    sudo -u "$USER_NAME" cp -r "$TEMPLATE_SOURCE"/* "$WAL_TEMPLATES/"
    print_success "✅ Copied all pywal templates"
    
    # List what was copied
    echo "Templates installed:"
    ls -1 "$WAL_TEMPLATES" | sed 's/^/   - /'
else
    print_error "Template directory not found: $TEMPLATE_SOURCE"
fi

# ----------------------------
# Create Symlinks to Pywal Cache
# ----------------------------
print_header "Creating symlinks to pywal cache"

# Waybar CSS symlink
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
print_success "✅ Waybar: style.css → ~/.cache/wal/waybar-style.css"

# Mako config symlink
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
print_success "✅ Mako: config → ~/.cache/wal/mako-config"

# Kitty config symlink
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/kitty"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
print_success "✅ Kitty: kitty.conf → ~/.cache/wal/kitty.conf"

# Hyprland colors symlink
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"
print_success "✅ Hyprland: colors-hyprland.conf → ~/.cache/wal/colors-hyprland.conf"

# ----------------------------
# Copy Scripts
# ----------------------------
print_header "Copying user scripts"
if [[ -d "$SCRIPTS_SRC" ]]; then
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/*.sh "$CONFIG_DIR/scripts/" 2>/dev/null || true
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/*.py "$CONFIG_DIR/scripts/" 2>/dev/null || true
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*.sh
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*.py 2>/dev/null || true
    print_success "✅ User scripts copied and made executable"
fi

# Screenshot script is now in the repo's scripts/ folder
# It will be copied with the other scripts above
print_success "✅ Screenshot script copied with other user scripts"

# ----------------------------
# Copy Wallpapers
# ----------------------------
print_header "Copying Wallpapers"
WALLPAPER_SRC="$REPO_ROOT/Pictures/Wallpapers"
if [[ -d "$WALLPAPER_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures"
    sudo -u "$USER_NAME" cp -rf "$WALLPAPER_SRC" "$USER_HOME/Pictures/"
    print_success "✅ Wallpapers copied"
fi

# ----------------------------
# Enable SDDM
# ----------------------------
print_header "Setting up SDDM"
run_command "systemctl enable sddm.service" "Enable SDDM login manager"

# ----------------------------
# Optional SDDM Theme Setup
# ----------------------------
print_header "Optional: Install SDDM Theme (NeonSky)"

read -rp "Do you want to install the NeonSky SDDM theme? (y/N): " INSTALL_SDDM_THEME
INSTALL_SDDM_THEME=${INSTALL_SDDM_THEME,,}  # lowercase

if [[ "$INSTALL_SDDM_THEME" == "y" || "$INSTALL_SDDM_THEME" == "yes" ]]; then
    TEMP_DIR=$(mktemp -d)
    print_header "Cloning NeonSky theme into $TEMP_DIR"
    run_command "git clone https://github.com/Saltyfunnel/sddm-neonsky-theme.git $TEMP_DIR/sddm-neonsky-theme" "Clone NeonSky theme"

    print_header "Installing NeonSky theme"
    run_command "cd $TEMP_DIR/sddm-neonsky-theme && sudo sh install.sh" "Run NeonSky install.sh"

    print_success "✅ NeonSky SDDM theme installed!"
    rm -rf "$TEMP_DIR"
else
    print_success "Skipped NeonSky SDDM theme installation"
fi


# ----------------------------
# Final message
# ----------------------------
print_success "\n✅ Installation complete!"
echo -e "\n╔════════════════════════════════════════════════════════════╗"
echo -e "║         Pywal Template System Setup Complete! 🎨          ║"
echo -e "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Configuration Structure:"
echo "   • Static configs: ~/.config/{hypr,waybar,yazi,fastfetch}/"
echo "   • Pywal templates: ~/.config/wal/templates/"
echo "   • Generated configs: ~/.cache/wal/ (symlinked)"
echo ""
echo "🎨 How the theming works:"
echo "   1. Templates contain color variables: {color1}, {background}, etc."
echo "   2. Run: setwall.sh <wallpaper>"
echo "   3. Pywal generates colors from wallpaper"
echo "   4. Templates are processed with new colors"
echo "   5. Symlinked configs update automatically"
echo "   6. Services reload with new theme"
echo ""
echo "🚀 Next Steps:"
echo "   1. Reboot or log out"
echo "   2. Select 'Hyprland' in SDDM"
echo "   3. Run: ~/.config/scripts/setwall.sh"
echo "   4. Pick a wallpaper with: Super+W"
echo ""
echo "📖 Keybinds:"
echo "   • Super+W = Wallpaper picker"
echo "   • Super+D = App launcher"
echo "   • Super+Return = Terminal"
echo "   • Super+F = File manager (Yazi)"
echo ""
print_success "Enjoy your themed Hyprland setup! 🎉"
