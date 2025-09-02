#!/bin/bash
set -euo pipefail

# ============================================================
#                     Helper Functions
# ============================================================
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

run_command() {
  local cmd="$1"
  local description="$2"
  print_info "\n$description..."
  if eval "$cmd"; then
    print_success "$description completed."
  else
    print_error "$description failed."
    exit 1
  fi
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
    else
      print_success "Arch Linux detected. Proceeding."
    fi
  else
    print_error "/etc/os-release not found. Cannot determine OS."
  fi
}

# ============================================================
#                     Initialization
# ============================================================
check_root
check_os

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

print_bold_blue "\n🚀 Starting Full Hyprland Setup"
echo "-------------------------------------"

# ============================================================
#                     Phase 1: Prerequisites
# ============================================================
print_header "Phase 1: Prerequisites Setup"

run_command "pacman -Syyu --noconfirm" "Update system packages"

# Install essential tools
run_command "pacman -S --noconfirm --needed git base-devel rust cargo meson ninja" "Install essential build tools and Rust"

# -------------------------------
# Packages categorized
# -------------------------------
CORE_PACKAGES=(
  pipewire wireplumber pamixer brightnessctl
  sddm firefox kitty nano tar gnome-disk-utility code mpv dunst pacman-contrib exo
  polkit polkit-gnome hyprland rofi swww waybar hyprpicker hyprlock hypridle
  yazi python-pywal grim slurp fastfetch starship
)

FONT_PACKAGES=(
  ttf-cascadia-code
  ttf-fira-code
  ttf-fira-mono
  ttf-fira-sans
  ttf-jetbrains-mono
  ttf-iosevka-nerd
)

FILE_PACKAGES=(
  thunar thunar-archive-plugin thunar-volman
  tumbler ffmpegthumbnailer file-roller
  gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb
)

THEME_PACKAGES=(
  python-pywal
)

MENU_PACKAGES=(
  wofi
)

# Merge all packages
PACKAGES=("${CORE_PACKAGES[@]}" "${FONT_PACKAGES[@]}" "${FILE_PACKAGES[@]}" "${THEME_PACKAGES[@]}" "${MENU_PACKAGES[@]}")

run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages"

# Enable services
run_command "systemctl enable --now polkit.service" "Enable and start polkit daemon"
run_command "systemctl enable sddm.service" "Enable SDDM display manager"

# ============================================================
#                     Phase 2: Copy Configs
# ============================================================
print_header "Phase 2: Copying Configurations"

CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hypr"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

copy_as_user() {
  local src="$1"
  local dest="$2"
  if [ ! -d "$src" ]; then
    print_warning "Source folder not found: $src"
    return 1
  fi
  sudo -u "$USER_NAME" mkdir -p "$dest"
  cp -r "$src"/* "$dest"
  chown -R "$USER_NAME:$USER_NAME" "$dest"
}

# Copy all relevant configs
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/rofi" "$CONFIG_DIR/rofi"
copy_as_user "$REPO_DIR/configs/dunst" "$CONFIG_DIR/dunst"
copy_as_user "$REPO_DIR/configs/kitty" "$CONFIG_DIR/kitty"
copy_as_user "$ASSETS_SRC/wallpapers" "$ASSETS_DEST/wallpapers"

# ============================================================
#                     Phase 2b: Shell Enhancements
# ============================================================
# Fastfetch in shells (only config)
for rc_file in ".bashrc" ".zshrc"; do
    RC_PATH="$USER_HOME/$rc_file"
    if [ ! -f "$RC_PATH" ]; then
        sudo -u "$USER_NAME" touch "$RC_PATH"
    fi
    if ! grep -qxF "fastfetch" "$RC_PATH"; then
        echo -e "\n# Show system info on terminal start\nfastfetch" | sudo -u "$USER_NAME" tee -a "$RC_PATH" >/dev/null
    fi
done

# Starship prompt
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
if [ -f "$STARSHIP_SRC" ]; then
    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
    chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
fi

for rc_pair in ".bashrc:bash" ".zshrc:zsh"; do
    shell_rc="${rc_pair%%:*}"
    shell_name="${rc_pair##*:}"
    RC_PATH="$USER_HOME/$shell_rc"
    STARSHIP_LINE="eval \"\$(starship init $shell_name)\""
    if ! grep -qxF "$STARSHIP_LINE" "$RC_PATH"; then
        echo -e "\n# Starship prompt\n$STARSHIP_LINE" | sudo -u "$USER_NAME" tee -a "$RC_PATH" >/dev/null
    fi
done

# ============================================================
#                     Phase 2c: Copy select-wallpaper.sh
# ============================================================
print_header "Phase 2c: Copy select-wallpaper.sh"

SCRIPTS_DIR="$CONFIG_DIR/hypr/scripts"
SELECT_WALLPAPER_SRC="$REPO_DIR/scripts/select-wallpaper.sh"
SELECT_WALLPAPER_DEST="$SCRIPTS_DIR/select-wallpaper.sh"

if [ -f "$SELECT_WALLPAPER_SRC" ]; then
    sudo -u "$USER_NAME" mkdir -p "$SCRIPTS_DIR"
    cp "$SELECT_WALLPAPER_SRC" "$SELECT_WALLPAPER_DEST"
    chown "$USER_NAME:$USER_NAME" "$SELECT_WALLPAPER_DEST"
    chmod +x "$SELECT_WALLPAPER_DEST"
    print_success "✅ select-wallpaper.sh copied to $SELECT_WALLPAPER_DEST and made executable."
else
    print_warning "select-wallpaper.sh not found in $SELECT_WALLPAPER_SRC. Please add it to your repo."
fi

# ============================================================
#                     Phase 3: GPU Drivers
# ============================================================
print_header "Phase 3: GPU Setup"
GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)
if echo "$GPU_INFO" | grep -qi "nvidia"; then
  print_bold_blue "NVIDIA GPU detected."
  run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers"
elif echo "$GPU_INFO" | grep -qi "amd"; then
  print_bold_blue "AMD GPU detected."
  run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers"
elif echo "$GPU_INFO" | grep -qi "intel"; then
  print_bold_blue "Intel GPU detected."
  run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers"
else
  print_warning "No supported GPU detected. Info: $GPU_INFO"
fi

# ============================================================
#                     Done
# ============================================================
print_bold_blue "\n✅ Setup Complete! Reboot to apply changes."
