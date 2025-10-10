#!/bin/bash
# Minimal Hyprland Installer with user configs (Bash only)
set -euo pipefail

# ----------------------------
# Helper functions
# ----------------------------
print_header()    { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success()   { echo -e "\e[32m$1\e[0m"; }
print_warning()   { echo -e "\e[33mWarning: $1\e[0m" >&2; }
print_error()     { echo -e "\e[31mError: $1\e[0m" >&2; exit 1; }

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
HYPR_CONFIG_SRC="$REPO_ROOT/configs/hypr/hyprland.conf"
COLOR_FILE_SRC="$REPO_ROOT/configs/hypr/colors-hyprland.conf"
WAYBAR_CONFIG_SRC="$REPO_ROOT/configs/waybar"
SCRIPTS_SRC="$REPO_ROOT/scripts"
FASTFETCH_SRC="$REPO_ROOT/configs/fastfetch/config.jsonc"

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
    # Core system + Hyprland essentials
    hyprland waybar swww dunst grim slurp kitty nano wget jq
    sddm polkit polkit-kde-agent code curl bluez bluez-utils blueman
    thunar gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 chafa nwg-look
    thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    firefox yazi fastfetch starship mpv gnome-disk-utility pavucontrol

    # GUI / Wayland / Fonts
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono
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
    tofi
)
for pkg in "${AUR_PACKAGES[@]}"; do
    if yay -Qs "^$pkg$" &>/dev/null; then
        print_success "✅ $pkg is already installed"
    else
        run_command "sudo -u $USER_NAME yay -S --noconfirm $pkg" "Install $pkg from AUR"
    fi
done

# ----------------------------
# Shell Setup (Bash only)
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
wal -r && clear

# Initialize Starship prompt
eval "$(starship init bash)"

# Run fastfetch after login
fastfetch
EOF
    print_success "Minimal .bashrc created with wal + fastfetch + starship"
fi

# ----------------------------
# Copy Hyprland configs
# ----------------------------
print_header "Copying Hyprland configs"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/hypr"
[[ -f "$HYPR_CONFIG_SRC" ]] && sudo -u "$USER_NAME" cp "$HYPR_CONFIG_SRC" "$CONFIG_DIR/hypr/hyprland.conf" && print_success "Copied hyprland.conf"
[[ -f "$COLOR_FILE_SRC" ]] && sudo -u "$USER_NAME" cp "$COLOR_FILE_SRC" "$CONFIG_DIR/hypr/colors-hyprland.conf" && print_success "Copied colors-hyprland.conf"

# ----------------------------
# Copy Waybar config
# ----------------------------
print_header "Copying Waybar config"
if [[ -d "$WAYBAR_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/waybar"
    sudo -u "$USER_NAME" cp -rf "$WAYBAR_CONFIG_SRC/." "$CONFIG_DIR/waybar/"
    print_success "Waybar config copied"
fi

# ----------------------------
# Copy Tofi config
# ----------------------------
print_header "Copying Tofi config"
TOFI_CONFIG_SRC="$REPO_ROOT/configs/tofi"

if [[ -d "$TOFI_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/tofi"
    sudo -u "$USER_NAME" cp -rf "$TOFI_CONFIG_SRC/." "$CONFIG_DIR/tofi/"
    print_success "Tofi config copied"
else
    print_warning "Tofi config folder not found at $TOFI_CONFIG_SRC"
fi

# ----------------------------
# Copy Yazi config
# ----------------------------
print_header "Copying Yazi config"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/yazi"
YAZI_FILES=("yazi.toml" "keybind.toml" "theme.toml")
for file in "${YAZI_FILES[@]}"; do
    SRC="$REPO_ROOT/configs/yazi/$file"
    DEST="$CONFIG_DIR/yazi/$file"
    [[ -f "$SRC" ]] && sudo -u "$USER_NAME" cp "$SRC" "$DEST" && print_success "Copied $file"
done

# ----------------------------
# Copy user scripts
# ----------------------------
print_header "Copying user scripts"
if [[ -d "$SCRIPTS_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/scripts"
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC/." "$CONFIG_DIR/scripts/"
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*.sh
    print_success "User scripts copied"
fi

# ----------------------------
# Copy Fastfetch config
# ----------------------------
print_header "Copying Fastfetch config"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/fastfetch"
[[ -f "$FASTFETCH_SRC" ]] && sudo -u "$USER_NAME" cp "$FASTFETCH_SRC" "$CONFIG_DIR/fastfetch/config.jsonc" && print_success "Fastfetch config copied"

# ----------------------------
# Copy Starship config
# ----------------------------
print_header "Copying Starship config"
STARSHIP_SRC="$REPO_ROOT/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"

if [[ -f "$STARSHIP_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$STARSHIP_SRC" "$STARSHIP_DEST"
    print_success "Starship config copied to $STARSHIP_DEST"
else
    print_warning "Starship config not found at $STARSHIP_SRC"
fi

# ----------------------------
# Copy Wallpapers
# ----------------------------
print_header "Copying Wallpapers"
WALLPAPER_SRC="$REPO_ROOT/Pictures/Wallpapers"
PICTURES_DEST="$USER_HOME/Pictures"
if [[ -d "$WALLPAPER_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$PICTURES_DEST"
    sudo -u "$USER_NAME" cp -rf "$WALLPAPER_SRC" "$PICTURES_DEST/"
    print_success "Wallpapers copied"
fi

# ----------------------------
# Enable SDDM
# ----------------------------
print_header "Setting up SDDM"
run_command "systemctl enable sddm.service" "Enable SDDM login manager"

# ----------------------------
# Final message
# ----------------------------
print_success "✅ Installation complete!"
echo -e "\nYou can now log out and select Hyprland session in SDDM."
