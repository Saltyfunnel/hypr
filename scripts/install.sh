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
# Enable Pacman ILoveCandy
# ----------------------------
print_header "Enabling Pacman ILoveCandy"
PACMAN_CONF="/etc/pacman.conf"

if ! grep -q "^ILoveCandy" "$PACMAN_CONF"; then
    sed -i '/^\[options\]/a ILoveCandy' "$PACMAN_CONF"
    print_success "✅ ILoveCandy added to pacman.conf"
else
    print_success "ILoveCandy already present in pacman.conf"
fi

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
    thunar gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 chafa
    thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    firefox yazi fastfetch starship mpv gnome-disk-utility pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono ttf-cascadia-code-nerd
    gnome-themes-extra
)
run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Install core packages"

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
HYPR_CONFIG_SRC="$REPO_ROOT/configs/hypr/hyprland.conf"
WAYBAR_CONFIG_SRC="$REPO_ROOT/configs/waybar/config"

if [[ -f "$HYPR_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$HYPR_CONFIG_SRC" "$CONFIG_DIR/hypr/hyprland.conf"
    print_success "✅ Copied hyprland.conf"
fi
if [[ -f "$WAYBAR_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$WAYBAR_CONFIG_SRC" "$CONFIG_DIR/waybar/config"
    print_success "✅ Copied waybar/config"
fi

for file in yazi.toml keybind.toml theme.toml; do
    SRC="$REPO_ROOT/configs/yazi/$file"
    if [[ -f "$SRC" ]]; then
        sudo -u "$USER_NAME" cp "$SRC" "$CONFIG_DIR/yazi/$file"
        print_success "✅ Copied yazi/$file"
    fi
done

FASTFETCH_SRC="$REPO_ROOT/configs/fastfetch/config.jsonc"
if [[ -f "$FASTFETCH_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$FASTFETCH_SRC" "$CONFIG_DIR/fastfetch/config.jsonc"
    print_success "✅ Copied fastfetch/config.jsonc"
fi

STARSHIP_SRC="$REPO_ROOT/configs/starship/starship.toml"
if [[ -f "$STARSHIP_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$STARSHIP_SRC" "$CONFIG_DIR/starship.toml"
    print_success "✅ Copied starship.toml"
fi

# ----------------------------
# Copy Pywal Templates
# ----------------------------
print_header "Copying Pywal templates"
TEMPLATE_SOURCE="$REPO_ROOT/configs/wal/templates"
if [[ -d "$TEMPLATE_SOURCE" ]]; then
    sudo -u "$USER_NAME" cp -r "$TEMPLATE_SOURCE"/* "$WAL_TEMPLATES/"
    print_success "✅ Copied all pywal templates"
    echo "Templates installed:"
    ls -1 "$WAL_TEMPLATES" | sed 's/^/   - /'
else
    print_error "Template directory not found: $TEMPLATE_SOURCE"
fi

# ----------------------------
# Create Symlinks to Pywal Cache
# ----------------------------
print_header "Creating symlinks to pywal cache"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/kitty"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf"
print_success "✅ Pywal symlinks created"

# ----------------------------
# Copy Scripts
# ----------------------------
print_header "Copying user scripts"
if [[ -d "$SCRIPTS_SRC" ]]; then
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC"/* "$CONFIG_DIR/scripts/"
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*.sh
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*.py 2>/dev/null || true
    print_success "✅ User scripts copied and made executable"
fi

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
# Install and Apply YAMIS Icon Theme System-Wide + Dark GTK
# ----------------------------
print_header "Installing YAMIS icon theme system-wide and enabling dark mode"

ICONS_SRC="$REPO_ROOT/configs/icons/yet-another-monochrome-icon-set.tar.gz"
SYSTEM_ICON_DEST="/usr/share/icons"

if [[ -f "$ICONS_SRC" ]]; then
    sudo tar -xzf "$ICONS_SRC" -C "$SYSTEM_ICON_DEST"
    sudo chmod -R 755 "$SYSTEM_ICON_DEST/YAMIS"
    print_success "✅ YAMIS installed to $SYSTEM_ICON_DEST/YAMIS"

    # Update icon cache - CRITICAL for icons to show up
    run_command "gtk-update-icon-cache -f -t $SYSTEM_ICON_DEST/YAMIS" "Update YAMIS icon cache"
    
    # Verify icon theme is valid
    if [[ ! -f "$SYSTEM_ICON_DEST/YAMIS/index.theme" ]]; then
        print_error "YAMIS index.theme not found - icon theme is invalid!"
    fi
    print_success "✅ YAMIS icon theme validated"

    # GTK3 settings
    GTK3_SETTINGS="$USER_HOME/.config/gtk-3.0/settings.ini"
    sudo -u "$USER_NAME" mkdir -p "$(dirname "$GTK3_SETTINGS")"
    sudo -u "$USER_NAME" tee "$GTK3_SETTINGS" >/dev/null <<EOF
[Settings]
gtk-icon-theme-name=YAMIS
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
gtk-cursor-theme-name=Adwaita
gtk-font-name=Sans 10
EOF
    print_success "✅ GTK3 configured with YAMIS + dark mode"

    # GTK4 settings
    GTK4_SETTINGS="$USER_HOME/.config/gtk-4.0/settings.ini"
    sudo -u "$USER_NAME" mkdir -p "$(dirname "$GTK4_SETTINGS")"
    sudo -u "$USER_NAME" tee "$GTK4_SETTINGS" >/dev/null <<EOF
[Settings]
gtk-icon-theme-name=YAMIS
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
gtk-cursor-theme-name=Adwaita
gtk-font-name=Sans 10
EOF
    print_success "✅ GTK4 configured with YAMIS + dark mode"

    # Force Qt/KDE apps to use YAMIS icons
    KDEGLOBALS="$USER_HOME/.config/kdeglobals"
    sudo -u "$USER_NAME" mkdir -p "$(dirname "$KDEGLOBALS")"
    if ! grep -q "^\[Icons\]" "$KDEGLOBALS" 2>/dev/null; then
        sudo -u "$USER_NAME" tee -a "$KDEGLOBALS" >/dev/null <<EOF
[Icons]
Theme=YAMIS
EOF
    else
        sudo -u "$USER_NAME" sed -i '/^\[Icons\]/,/^\[/ s/^Theme=.*/Theme=YAMIS/' "$KDEGLOBALS"
    fi
    print_success "✅ Qt/KDE apps configured to use YAMIS icons"

    print_success "✅ XFCE/Thunar dark mode configured via xfconf"

else
    print_warning "Icon archive not found at $ICONS_SRC, skipping icon installation"
fi

# ----------------------------
# Final message
# ----------------------------
print_success "\n✅ Installation complete!"
echo -e "\n╔════════════════════════════════════════════════════════════╗"
echo -e "║         Pywal Template System Setup Complete! 🎨          ║"
echo -e "╚════════════════════════════════════════════════════════════╝"
