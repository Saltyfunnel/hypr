#!/bin/bash
# Minimal Hyprland Installer with user configs (fixed paths)
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
    hyprland waybar swww dunst grim slurp kitty nano wget jq
    sddm polkit polkit-kde-agent code curl bluez bluez-utils blueman
    thunar gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 chafa nwg-look
    thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    firefox yazi fastfetch mpv gnome-disk-utility pavucontrol
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
    # Add additional AUR packages here
)
for pkg in "${AUR_PACKAGES[@]}"; do
    if yay -Qs "^$pkg$" &>/dev/null; then
        print_success "✅ $pkg is already installed"
    else
        run_command "sudo -u $USER_NAME yay -S --noconfirm $pkg" "Install $pkg from AUR"
    fi
done

# ----------------------------
# Shell Setup (Bash or Zsh)
# ----------------------------
print_header "Shell Setup"

echo "Choose your default shell:"
echo "1) Bash"
echo "2) Zsh (with Powerlevel10k)"
read -rp "Enter choice [1-2]: " SHELL_CHOICE

case "$SHELL_CHOICE" in
    1)
        print_success "You chose Bash"
        run_command "chsh -s $(command -v bash) $USER_NAME" "Set Bash as default shell"
        ;;
    2)
        print_success "You chose Zsh with Powerlevel10k"

        # Install zsh via pacman
        run_command "pacman -S --noconfirm --needed zsh" "Install Zsh"

        # Install Powerlevel10k via AUR
        run_command "sudo -u $USER_NAME yay -S --noconfirm zsh-theme-powerlevel10k" "Install Powerlevel10k"

        # Set Zsh as default shell
        run_command "chsh -s $(command -v zsh) $USER_NAME" "Set Zsh as default shell"

        # Copy Powerlevel10k config if present in repo
        P10K_CONFIG_SRC="$REPO_ROOT/configs/.p10k.zsh"
        if [[ -f "$P10K_CONFIG_SRC" ]]; then
            sudo -u "$USER_NAME" cp "$P10K_CONFIG_SRC" "$USER_HOME/.p10k.zsh"
            print_success "Powerlevel10k config copied"
        else
            print_warning "No .p10k.zsh config found in $REPO_ROOT/configs"
        fi

        # Handle .zshrc
        ZSHRC_DEST="$USER_HOME/.zshrc"
        ZSHRC_SRC="$REPO_ROOT/configs/.zshrc"

        if [[ -f "$ZSHRC_DEST" ]]; then
            print_warning ".zshrc already exists in home, leaving it untouched"
        elif [[ -f "$ZSHRC_SRC" ]]; then
            sudo -u "$USER_NAME" cp "$ZSHRC_SRC" "$ZSHRC_DEST"
            print_success ".zshrc copied from repo"
        else
            print_warning "No .zshrc found in repo, creating a minimal one"
            cat <<'EOF' | sudo -u "$USER_NAME" tee "$ZSHRC_DEST" >/dev/null
# Enable Powerlevel10k if installed
if [ -f /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme ]; then
  source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
fi

# Load user-specific Powerlevel10k config if present
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Restore Pywal colors and clear terminal
wal -r && clear

# Run fastfetch after login
fastfetch
EOF
            print_success "Minimal .zshrc created with wal + fastfetch"
        fi
        ;;
    *)
        print_warning "Invalid choice. Defaulting to Bash."
        run_command "chsh -s $(command -v bash) $USER_NAME" "Set Bash as default shell"
        ;;
esac

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
# Copy .bashrc
# ----------------------------
print_header "Copying .bashrc"
[[ -f "$REPO_ROOT/configs/.bashrc" ]] && sudo -u "$USER_NAME" cp "$REPO_ROOT/configs/.bashrc" "$USER_HOME/.bashrc" && print_success ".bashrc copied"

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
