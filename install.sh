#!/bin/bash
set -euo pipefail

# ------------------------
# Variables
# ------------------------
USER_NAME="${SUDO_USER:-$USER}"

# ------------------------
# Helper functions
# ------------------------
print_info()    { printf "\033[0;34m%s\033[0m\n" "$1"; }
print_success() { printf "\033[0;32m%s\033[0m\n" "$1"; }
print_warning() { printf "\033[0;33m%s\033[0m\n" "$1"; }
print_error()   { printf "\033[0;31m%s\033[0m\n" "$1"; }
print_header()  { printf "\n\033[1;34m==> %s\033[0m\n" "$1"; }

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        print_error "This script must be run as root."
        exit 1
    fi
}

check_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "arch" ]]; then
            print_success "Arch Linux detected. Proceeding..."
        else
            print_warning "This script is intended for Arch Linux. Detected: $PRETTY_NAME"
        fi
    else
        print_warning "/etc/os-release not found. Unable to verify OS."
    fi
}

run_command() {
    local cmd="$1"
    local description="$2"

    print_info "Running: $description"
    if ! eval "$cmd"; then
        print_error "Failed: $description"
        exit 1
    fi
    print_success "Completed: $description"
}

# ------------------------
# Installation functions
# ------------------------
install_base_system() {
    print_header "Updating system"
    run_command "pacman -Syyu --noconfirm" "System package update"
}

install_pacman_packages() {
    print_header "Installing core Pacman packages..."
    local packages=(
        hyprland waybar dunst grim htop iwd kitty nano openssh polkit polkit-kde-agent
        qt5-wayland qt6-wayland slurp smartmontools wget rofi wpa_supplicant
        xdg-desktop-portal-hyprland xdg-utils lite-xl firefox thunar gvfs
        gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 lxappearance
        thunar-archive-plugin thunar-volman ffmpegthumbnailer file-roller tumbler
        python-pywal python-gobject gtk3 sddm yazi fastfetch mpv
    )
    run_command "pacman -S --noconfirm --needed ${packages[*]}" "Pacman package installation"

    print_header "Enabling system services..."
    run_command "systemctl enable --now polkit.service" "Enable polkit"
    run_command "systemctl enable sddm.service" "Enable SDDM"
}

install_gpu_drivers() {
    print_header "Detecting GPU and installing drivers..."
    local gpu_info
    if ! gpu_info=$(lspci | grep -Ei "VGA|3D"); then
        print_warning "Could not detect GPU. Skipping driver installation."
        return
    fi

    if echo "$gpu_info" | grep -qi "nvidia"; then
        run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "NVIDIA drivers"
    elif echo "$gpu_info" | grep -qi "amd"; then
        run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "AMD drivers"
    elif echo "$gpu_info" | grep -qi "intel"; then
        run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Intel drivers"
    else
        print_warning "No supported GPU detected. Skipping driver installation."
    fi
}

install_yay() {
    print_header "Installing yay (AUR helper)..."
    if command -v yay &>/dev/null; then
        print_success "Yay is already installed."
        return
    fi

    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Set permissions for yay build"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay as user"
    run_command "rm -rf /tmp/yay" "Clean up"
}

install_aur_packages() {
    print_header "Installing AUR packages..."
    local packages=(
        python-pywalfox
    )
    if [[ ${#packages[@]} -gt 0 ]]; then
        run_command "sudo -u $USER_NAME yay -S --noconfirm --sudoloop ${packages[*]}" "AUR package installation"
    fi
}

# ------------------------
# Configuration functions
# ------------------------
copy_hyprland_conf() {
    print_header "Copying Hyprland config..."
    local source_file="./configs/hypr/hyprland.conf"
    local dest_dir="/home/$USER_NAME/.config/hypr"

    if [[ ! -f "$source_file" ]]; then
        print_warning "Hyprland config not found. Skipping."
        return
    fi

    mkdir -p "$dest_dir"
    cp -f "$source_file" "$dest_dir/hyprland.conf"
    chown "$USER_NAME:$USER_NAME" "$dest_dir/hyprland.conf"
    print_success "Hyprland config copied to $dest_dir/hyprland.conf"
}

copy_waybar_config() {
    print_header "Copying Waybar config..."
    local source_dir="./configs/waybar"
    local dest_dir="/home/$USER_NAME/.config/waybar"

    if [[ ! -d "$source_dir" ]]; then
        print_warning "Waybar config directory not found. Skipping."
        return
    fi

    mkdir -p "$dest_dir"
    cp -f "$source_dir/config" "$dest_dir/config"
    cp -f "$source_dir/style.css" "$dest_dir/style.css"
    chown -R "$USER_NAME:$USER_NAME" "$dest_dir"
    print_success "Waybar config copied to $dest_dir"
}
# ------------------------
# Main function
# ------------------------
main() {
    check_root
    check_os

    install_base_system
    install_gpu_drivers
    install_pacman_packages
    install_yay
    install_aur_packages

    copy_hyprland_conf
    copy_waybar_config
    
    print_header "✅ Environment setup complete!"
    print_success "You can now reboot and log in via SDDM. Hyprland and Waybar will launch with your configs."
}

main
