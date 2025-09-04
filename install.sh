#!/bin/bash
set -euo pipefail

# ------------------------
# Variables
# ------------------------
USER_NAME="${SUDO_USER:-$USER}"

# ------------------------
# Helper functions
# ------------------------
print_info()    { echo -e "\033[0;34m$1\033[0m"; }
print_success() { echo -e "\033[0;32m$1\033[0m"; }
print_warning() { echo -e "\033[0;33m$1\033[0m"; }
print_error()   { echo -e "\033[0;31m$1\033[0m"; }
print_header()  { echo -e "\n\033[1;34m==> $1\033[0m"; }

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        print_error "Please run this script as root."
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "arch" ]]; then
            print_warning "This script is designed for Arch Linux. Detected: $PRETTY_NAME"
        else
            print_success "Arch Linux detected. Proceeding."
        fi
    else
        print_warning "/etc/os-release not found. Cannot determine OS."
    fi
}

run_command() {
    local cmd="$1"
    local description="$2"

    print_info "Running: $cmd"
    if ! eval "$cmd"; then
        print_error "Failed: $description"
        exit 1
    else
        print_success "$description completed successfully."
    fi
}

# ------------------------
# Install functions
# ------------------------
install_base_system() {
    print_header "Updating system"
    run_command "pacman -Syyu --noconfirm" "System package update"
}

install_gpu_drivers() {
    print_header "Detecting GPU and installing drivers"
    GPU_INFO=$(lspci | grep -Ei "VGA|3D")

    if echo "$GPU_INFO" | grep -qi "nvidia"; then
        run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
    elif echo "$GPU_INFO" | grep -qi "amd"; then
        run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
    elif echo "$GPU_INFO" | grep -qi "intel"; then
        run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
    else
        print_warning "No supported GPU detected. Skipping GPU driver installation."
    fi
}

install_yay() {
    print_header "Installing yay (AUR helper)"
    if ! command -v yay &>/dev/null; then
        run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
        run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository"
        run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix permissions"
        run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay"
        run_command "rm -rf /tmp/yay" "Clean up yay directory"
    else
        print_success "Yay is already installed."
    fi
}

install_pacman_packages() {
    print_header "Installing Pacman packages"

PACMAN_PACKAGES=(
    hyprland dunst grim htop iwd kitty nano openssh polkit polkit-kde-agent
    qt5-wayland qt6-wayland slurp smartmontools wget rofi wpa_supplicant
    xdg-desktop-portal-hyprland xdg-utils lite-xl firefox thunar gvfs
    gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 lxappearance
    thunar-archive-plugin thunar-volman ffmpegthumbnailer file-roller tumbler
    python-pywal python-gobject gtk3 sddm yazi fastfetch mpv
)

    run_command "pacman -S --noconfirm ${PACMAN_PACKAGES[*]}" "Install core system packages"

    # Enable services
    run_command "systemctl enable --now polkit.service" "Enable polkit"
    run_command "systemctl enable sddm.service" "Enable SDDM"
}

install_aur_packages() {
    print_header "Installing AUR packages"

    AUR_PACKAGES=(
        yay python-pywalfox
    )

    run_command "sudo -u $USER_NAME yay -S --noconfirm --sudoloop ${AUR_PACKAGES[*]}" "Install AUR packages"
}

# ------------------------
# Main function
# ------------------------
main() {
    check_root
    check_os

    install_base_system
    install_gpu_drivers
    install_yay
    install_pacman_packages
    install_aur_packages

    print_header "✅ Environment setup complete!"
    echo "Hyprland will run with default settings. Log in via SDDM."
}

main
