#!/bin/bash
# Minimal Hyprdots installer for Arch Linux with Zsh and Hyprland, handling conflicts and setting up SDDM.
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

install_package() {
    local pkg="$1"
    if ! pacman -Qi "$pkg" &>/dev/null; then
        echo "Installing $pkg..."
        if ! pacman -S --noconfirm "$pkg"; then
            echo "Conflict detected while installing $pkg."
            echo "Pacman output above shows conflicting packages."
            read -p "Do you want to remove conflicting packages and continue? [y/N]: " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                pacman -Rns "$pkg" --noconfirm || true
                pacman -S --noconfirm "$pkg"
            else
                print_warning "Skipping $pkg due to conflicts."
            fi
        fi
    else
        print_success "$pkg is already installed."
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
SAVED_CONFIGS="$SCRIPT_DIR/.config"  # Point to your repo .config folder

# --- Official Pacman Packages ---
print_header "Installing official Pacman packages"
PACMAN_PACKAGES=(
    git base-devel zsh kitty dunst fastfetch waybar
    hyprland hypridle hyprlock
    qt6 gtk3 gtk4
    pipewire wireplumber pamixer brightnessctl
    polkit polkit-gnome rofi sddm
)
for pkg in "${PACMAN_PACKAGES[@]}"; do
    install_package "$pkg"
done

# --- Install yay (AUR helper) ---
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

# --- AUR Packages ---
AUR_APPS=(waypaper qt6-kde qt6ct matugen spicetify python-pywal16 vesktop-themes)
print_header "Installing AUR apps"
for app in "${AUR_APPS[@]}"; do
    echo "Installing $app..."
    if ! sudo -u "$USER_NAME" yay -S --noconfirm "$app"; then
        print_warning "Failed to install $app. You may need to resolve conflicts manually."
    fi
done

# --- Set Zsh as Default Shell ---
print_header "Setting Zsh as default shell"
chsh -s /bin/zsh "$USER_NAME"
print_success "✅ Zsh set as default shell"

# --- GPU Drivers ---
print_header "Detecting GPU and installing drivers"
GPU_INFO=$(lspci | grep -Ei "VGA|3D")
if echo "$GPU_INFO" | grep -qi "nvidia"; then
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi "amd"; then
    pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau
elif echo "$GPU_INFO" | grep -qi "intel"; then
    pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel
else
    print_warning "No supported GPU detected"
fi

# --- Enable Services ---
print_header "Enabling system services"
systemctl enable --now polkit.service
systemctl enable --now sddm.service
print_success "✅ Polkit and SDDM services enabled. Graphical login will be available after reboot."

# --- Copy Configs from Repo .config ---
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

print_success "\n🎉 Installation complete! Reboot to apply all changes. You will now see the SDDM login screen."
