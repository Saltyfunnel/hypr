#!/bin/bash
# ==========================
# Full Hyprland Installer for Arch Linux
# Repo structure:
# hypr/
# ├── assets/
# │   └── wallpapers/
# ├── configs/
# │   ├── waybar/
# │   ├── hypr/
# │   ├── tofi/
# │   ├── fastfetch/
# │   ├── starship/
# │   └── dunst/
# └── scripts/
# ==========================

set -euo pipefail

# --------------------------
# Helper functions
# --------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_error()   { echo -e "${RED}$1${NC}"; }
print_success() { echo -e "${GREEN}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_info()    { echo -e "${BLUE}$1${NC}"; }
print_bold_blue() { echo -e "${BLUE}${BOLD}$1${NC}"; }
print_header()  { echo -e "\n${BOLD}${BLUE}==> $1${NC}"; }

ask_confirmation() {
  while true; do
    read -rp "$(print_warning "$1 (y/n): ")" -n 1
    echo
    case $REPLY in
      [Yy]) return 0 ;;
      [Nn]) print_error "Operation cancelled."; return 1 ;;
      *) print_error "Invalid input. Please answer y or n." ;;
    esac
  done
}

run_command() {
  local cmd="$1"
  local description="$2"
  local ask_confirm="${3:-yes}"
  local use_sudo="${4:-yes}"

  local full_cmd=""
  if [[ "$use_sudo" == "no" ]]; then
    full_cmd="sudo -u $SUDO_USER bash -c \"$cmd\""
  else
    full_cmd="$cmd"
  fi

  print_info "\nCommand: $full_cmd"
  if [[ "$ask_confirm" == "yes" ]]; then
    if ! ask_confirmation "$description"; then
      return 1
    fi
  else
    print_info "$description"
  fi

  until eval "$full_cmd"; do
    print_error "Command failed: $cmd"
    if [[ "$ask_confirm" == "yes" ]]; then
      if ! ask_confirmation "Retry $description?"; then
        print_warning "$description not completed."
        return 1
      fi
    else
      print_warning "$description failed, no retry (auto mode)."
      return 1
    fi
  done

  print_success "$description completed successfully."
  return 0
}

check_root() {
  if [[ "$EUID" -ne 0 ]]; then
    print_error "Please run as root."
    exit 1
  fi
}

check_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "arch" ]]; then
      print_warning "This script is designed for Arch Linux. Detected: $PRETTY_NAME"
      if ! ask_confirmation "Continue anyway?"; then
        exit 1
      fi
    else
      print_success "Arch Linux detected. Proceeding."
    fi
  else
    print_error "/etc/os-release not found. Cannot determine OS."
    if ! ask_confirmation "Continue anyway?"; then
      exit 1
    fi
  fi
}

# --------------------------
# Setup variables
# --------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")
CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hypr"
ASSETS_SRC="$REPO_DIR/assets"
CONFIG_SRC="$REPO_DIR/configs"

# --------------------------
# Helper functions for configs
# --------------------------
copy_as_user() {
    local src="$1"
    local dest="$2"
    if [ ! -d "$src" ]; then
        print_warning "Source folder not found: $src"
        return 1
    fi
    run_command "mkdir -p \"$dest\"" "Create destination directory $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy from $src to $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership for $dest" "no" "yes"
}

add_fastfetch_to_shell() {
    local shell_rc="$1"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local fastfetch_line='fastfetch --kitty-direct /home/'"$USER_NAME"'/.config/fastfetch/archkitty.png'
    if [ -f "$shell_rc_path" ] && ! grep -qF "$fastfetch_line" "$shell_rc_path"; then
        echo -e "\n# Run fastfetch on terminal start\n$fastfetch_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

add_starship_to_shell() {
    local shell_rc="$1"
    local shell_name="$2"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local starship_line='eval "$(starship init '"$shell_name"')"'
    if [ -f "$shell_rc_path" ] && ! grep -qF "$starship_line" "$shell_rc_path"; then
        echo -e "\n$starship_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

# --------------------------
# Start script
# --------------------------
check_root
check_os
print_bold_blue "\n🚀 Starting Full Hyprland + Pywal Setup"
echo "-------------------------------------"

# --------------------------
# Prerequisites
# --------------------------
print_header "Updating system and installing prerequisites"
run_command "pacman -Syyu --noconfirm" "Update system packages" "yes"

if ! command -v yay &>/dev/null; then
    print_info "Yay not found. Installing yay..."
    run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel" "yes"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repository" "no" "no"
    run_command "chown -R $USER_NAME:$USER_NAME /tmp/yay" "Fix ownership of yay build directory" "no" "no"
    run_command "cd /tmp/yay && sudo -u $USER_NAME makepkg -si --noconfirm" "Build and install yay" "no" "no"
    run_command "rm -rf /tmp/yay" "Clean up yay build directory" "no" "no"
else
    print_success "Yay is already installed."
fi

PACKAGES=(
  pipewire wireplumber pamixer brightnessctl
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans
  ttf-iosevka-nerd ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
  sddm kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo firefox yazi
  thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
  gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb
  polkit polkit-gnome
)

run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages" "yes"
run_command "systemctl enable --now polkit.service" "Enable polkit" "yes"
run_command "systemctl enable sddm.service" "Enable SDDM" "yes"

# --------------------------
# Utilities
# --------------------------
print_header "Installing Utilities and configs"
run_command "pacman -S --noconfirm waybar cliphist" "Install Waybar and Cliphist" "yes"
copy_as_user "$CONFIG_SRC/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$CONFIG_SRC/dunst" "$CONFIG_DIR/dunst"

run_command "yay -S --sudoloop --noconfirm tofi fastfetch swww hyprland hyprpicker hyprlock grimblast hypridle starship pywal16" "Install AUR utilities including pywal16" "yes" "no"

copy_as_user "$CONFIG_SRC/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$CONFIG_SRC/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$CONFIG_SRC/hypr" "$CONFIG_DIR/hypr"

STARSHIP_SRC="$CONFIG_SRC/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
if [ -f "$STARSHIP_SRC" ]; then
    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
    chown "$USER_NAME:$
