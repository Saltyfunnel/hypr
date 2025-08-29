#!/bin/bash
# Minimal Hyprdots installer for Arch Linux with Zsh and Hyprland.
set -euo pipefail

# --- Helper Functions ---
print_header() { echo -e "\n--- \e[1m\e[34m$1\e[0m ---"; }
print_success() { echo -e "\e[32m$1\e[0m"; }
print_warning() { echo -e "\e[33mWarning: $1\e[0m" >&2; }
print_error() { echo -e "\e[31mError: $1\e[0m" >&2; exit 1; }

copy_configs() {
    local src="$1" dst="$2" name="$3"
    if [ -d "$src" ]; then
        sudo -u "$USER_NAME" mkdir -p "$dst"
        sudo -u "$USER_NAME" cp -r "$src/." "$dst"
        print_success "✅ Copied $name from $src to $dst"
    else
        print_warning "Config $name not found at $src, skipping."
    fi
}

# --- Main Logic ---
if [ "$EUID" -ne 0 ]; then
    print_error "Run this script with sudo."
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAVED_CONFIGS="$SCRIPT_DIR/configs"

# --- Install System Packages (Official Repos Only) ---
print_header "Installing official Pacman packages"
PACMAN_PACKAGES=(
    git base-devel zsh kitty dunst fastfetch waybar
    hyprland hypridle hyprlock
    qt6 gtk3 gtk4
    pipewire wireplumber pamixer brightnessctl
    polkit polkit-gnome
)
pacman -Syu --noconfirm "${PACMAN_PACKAGES[@]}"
print_success "✅ Official Pacman packages installed"

# --- Install AUR Packages ---
print_header "Installing yay (AUR helper)"
YAY_DIR="$USER_HOME/yay"
if [ ! -d "$YAY_DIR" ]; then
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/yay.git "$YAY_DIR"
    cd "$YAY_DIR"
    sudo -u "$USER_NAME" makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
else
    print_success "✅ yay already installed"
fi

# AUR-only packages
AUR_APPS=(waypaper qt6-kde qt6ct matugen rofi rofi-wayland rofi-emoji spicetify python-pywal16 vesktop-themes)
print_header "Installing AUR apps"
for app in "${AUR_APPS[@]}"; do
    sudo -u "$USER_NAME" yay -S --noconfirm "$app"
done
print_success "✅ All AUR apps installed"

# --- Set Zsh as Default Shell ---
print_header "Setting Zsh as default shell"
chsh -s /bin/zsh "$USER_NAME"
print_success "✅ Zsh set as default shell"

# --- GPU Detection & Drivers ---
print_header "Detecting GPU and installing drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_success "NVIDIA GPU detected"
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_success "AMD GPU detected"
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_success "Intel GPU detected"
    pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel
else
    print_warning "No supported GPU detected"
fi
print_success "✅ GPU drivers installed"

# --- Enable Services ---
print_header "Enabling system services"
systemctl enable --now polkit.service
print_success "✅ polkit service enabled"

# Optionally enable SDDM if present
if command -v sddm &>/dev/null; then
    systemctl enable --now sddm.service
    print_success "✅ SDDM service enabled"
fi

# --- Copy Hyprdots Configs ---
print_header "Copying saved Hyprdots configs to ~/.config"
CONFIGS_TO_COPY=(hypr kitty dunst fastfetch waybar waypaper rofi matugen spicetify vesktop wal/templates)
for cfg in "${CONFIGS_TO_COPY[@]}"; do
    copy_configs "$SAVED_CONFIGS/$cfg" "$CONFIG_DIR/$cfg" "$cfg"
done

# Copy starship.toml if exists
if [ -f "$SAVED_CONFIGS/starship/starship.toml" ]; then
    sudo -u "$USER_NAME" cp "$SAVED_CONFIGS/starship/starship.toml" "$CONFIG_DIR/"
    print_success "✅ Copied starship.toml"
fi

print_success "\n🎉 Installation complete! Reboot to apply all changes."
