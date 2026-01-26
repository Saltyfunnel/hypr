#!/bin/bash
# Universal Hyprland Installer - 2026 (AMD / NVIDIA / Intel)
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
    print_success "✅ $desc"
}

detect_bootloader() {
    if bootctl is-installed &>/dev/null; then
        echo "systemd-boot"
    elif command -v grub-mkconfig &>/dev/null; then
        echo "grub"
    else
        echo "unknown"
    fi
}

# ----------------------------
# Setup Variables
# ----------------------------
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_SRC="$REPO_ROOT/scripts"

# ----------------------------
# Checks
# ----------------------------
[[ "$EUID" -eq 0 ]] || print_error "Run as root: sudo $0"
command -v pacman &>/dev/null || print_error "pacman not found"

# ----------------------------
# System Update
# ----------------------------
print_header "System update"
run_command "pacman -Syyu --noconfirm" "Updating system"

# ----------------------------
# GPU Detection & Drivers
# ----------------------------
print_header "Detecting GPU & Installing Drivers"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)
BOOTLOADER=$(detect_bootloader)

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_header "NVIDIA GPU detected"

    run_command "pacman -S --noconfirm --needed \
        nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" \
        "Installing NVIDIA drivers"

    # Early KMS
    sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    run_command "mkinitcpio -P" "Rebuilding initramfs (NVIDIA)"

    # Kernel params
    if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
        print_header "Configuring systemd-boot kernel params"
        for entry in /boot/loader/entries/*.conf; do
            grep -q "nvidia_drm.modeset=1" "$entry" || \
                sed -i 's/^options /options nvidia_drm.modeset=1 /' "$entry"
        done

    elif [[ "$BOOTLOADER" == "grub" ]]; then
        print_header "Configuring GRUB kernel params"
        if [ -f /etc/default/grub ]; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 /' /etc/default/grub
            run_command "grub-mkconfig -o /boot/grub/grub.cfg" "Updating GRUB"
        fi
    else
        print_warning "Unknown bootloader — add nvidia_drm.modeset=1 manually if needed"
    fi

    GPU_VENDOR="nvidia"

elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_header "AMD GPU detected"

    run_command "pacman -S --noconfirm --needed \
        mesa \
        vulkan-radeon lib32-vulkan-radeon \
        libva-mesa-driver mesa-vdpau \
        xf86-video-amdgpu" \
        "Installing AMD GPU stack"

    GPU_VENDOR="amd"

elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_header "Intel GPU detected"

    run_command "pacman -S --noconfirm --needed \
        mesa \
        vulkan-intel lib32-vulkan-intel \
        libva-intel-driver libva-mesa-driver" \
        "Installing Intel GPU stack"

    GPU_VENDOR="intel"

else
    print_warning "Unknown GPU — installing generic Mesa stack"
    run_command "pacman -S --noconfirm --needed mesa vulkan-icd-loader" \
        "Installing generic GPU drivers"
    GPU_VENDOR="unknown"
fi

# ----------------------------
# Core Packages
# ----------------------------
print_header "Installing core packages"

PACMAN_PACKAGES=(
    hyprland waybar swww mako grim slurp kitty wget jq btop
    sddm polkit polkit-kde-agent code curl bluez bluez-utils blueman
    gvfs udiskie udisks2 firefox fastfetch starship mpv pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 trash-cli
    unzip p7zip tar gzip xz bzip2 unrar atool imv
    yazi ffmpegthumbnailer poppler imagemagick chafa
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-cascadia-code-nerd
)

run_command "pacman -S --noconfirm --needed ${PACMAN_PACKAGES[*]}" "Installing core packages"

run_command "systemctl enable --now bluetooth.service" "Enabling Bluetooth"

# ----------------------------
# Display Manager
# ----------------------------
print_header "Configuring SDDM (Wayland)"
mkdir -p /etc/sddm.conf.d
cat <<'EOF' > /etc/sddm.conf.d/10-wayland.conf
[General]
DisplayServer=wayland
EOF

systemctl enable sddm.service

# ----------------------------
# Install Yay
# ----------------------------
print_header "Installing yay (AUR helper)"

if ! command -v yay &>/dev/null; then
    run_command "pacman -S --noconfirm --needed git base-devel" "Installing base-devel"
    run_command "rm -rf /tmp/yay && git clone https://aur.archlinux.org/yay.git /tmp/yay" "Cloning yay"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay && cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" \
        "Building yay"
fi

# ----------------------------
# User Config Directories
# ----------------------------
print_header "Setting up user config directories"

sudo -u "$USER_NAME" mkdir -p \
    "$CONFIG_DIR"/{hypr,waybar,kitty,yazi,fastfetch,mako,scripts,themes} \
    "$USER_HOME/Pictures/Wallpapers"

# ----------------------------
# GPU-specific Hyprland env file
# ----------------------------
print_header "Writing GPU-specific Hyprland env"

GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu.conf"

case "$GPU_VENDOR" in
    nvidia)
        cat <<'EOF' > "$GPU_ENV_FILE"
env = LIBVA_DRIVER_NAME,nvidia
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1
EOF
        ;;
    *)
        echo "# No GPU-specific env needed" > "$GPU_ENV_FILE"
        ;;
esac

chown "$USER_NAME:$USER_NAME" "$GPU_ENV_FILE"

# ----------------------------
# Optional: Copy Repo Configs
# ----------------------------
print_header "Applying repo configs if present"

copy_if_exists() {
    local src="$1"
    local dest="$2"
    [[ -e "$src" ]] && sudo -u "$USER_NAME" cp -r "$src" "$dest"
}

copy_if_exists "$REPO_ROOT/configs/hypr/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf"
copy_if_exists "$REPO_ROOT/configs/waybar" "$CONFIG_DIR/"
copy_if_exists "$REPO_ROOT/configs/kitty" "$CONFIG_DIR/"
copy_if_exists "$REPO_ROOT/configs/yazi" "$CONFIG_DIR/"
copy_if_exists "$REPO_ROOT/configs/fastfetch" "$CONFIG_DIR/"
copy_if_exists "$REPO_ROOT/Pictures/Wallpapers" "$USER_HOME/Pictures/"

# ----------------------------
# Final Permissions
# ----------------------------
print_header "Fixing permissions"
chown -R "$USER_NAME:$USER_NAME" "$CONFIG_DIR" "$USER_HOME/Pictures"

# ----------------------------
# Done
# ----------------------------
print_success "Installation complete."
print_success "Reboot recommended."
