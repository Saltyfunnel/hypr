#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"
USER_HOME="/home/$SUDO_USER"

source "$SCRIPT_DIR/helper.sh"

check_root
check_os

print_header "Starting prerequisites setup..."

run_command "pacman -Syyu --noconfirm" "Update system packages" "yes"

if ! command -v yay &>/dev/null; then
  print_info "Yay not found. Installing yay..."
  run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel" "yes"
  run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository" "no" "no"
  run_command "chown -R $SUDO_USER:$SUDO_USER /tmp/yay" "Fix ownership of yay build directory" "no" "no"
  run_command "cd /tmp/yay && sudo -u $SUDO_USER makepkg -si --noconfirm" "Build and install yay" "no" "no"
  run_command "rm -rf /tmp/yay" "Clean up yay build directory" "no" "no"
else
  print_success "Yay is already installed."
fi

PACKAGES=(
  pipewire wireplumber pamixer brightnessctl
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
  ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
  sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
  thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
  gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb
  polkit polkit-gnome
)

run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages" "yes"
run_command "systemctl enable --now polkit.service" "Enable and start polkit daemon" "yes"
run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages" "yes"
run_command "systemctl enable sddm.service" "Enable SDDM display manager" "yes"
run_command "yay -S --sudoloop --noconfirm firefox" "Install Firefox browser" "yes" "no"

echo "------------------------------------------------------------------------"
