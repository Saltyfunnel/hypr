#!/bin/bash
set -euo pipefail

# ──────────────────────────────
# Helper functions (from helper.sh)
# ──────────────────────────────
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

# Run commands without confirmation
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

# ──────────────────────────────
# Setup
# ──────────────────────────────
check_root
check_os

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

print_bold_blue "\n🚀 Starting Full Hyprland Setup"
echo "-------------------------------------"

# ──────────────────────────────
# Phase 1: Prerequisites
# ──────────────────────────────
print_header "Prerequisites Setup"

run_command "pacman -Syyu --noconfirm" "Update system packages"

if ! command -v yay &>/dev/null; then
  print_info "Yay not found. Installing yay..."
  run_command "pacman -S --noconfirm --needed git base-devel" "Install git and base-devel"
  sudo -u "$USER_NAME" bash -c "
    cd /tmp &&
    git clone https://aur.archlinux.org/yay.git &&
    cd yay &&
    makepkg -si --noconfirm
  "
  rm -rf /tmp/yay
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

run_command "pacman -S --noconfirm ${PACKAGES[*]}" "Install system packages"
run_command "systemctl enable --now polkit.service" "Enable and start polkit daemon"
run_command "systemctl enable sddm.service" "Enable SDDM display manager"
sudo -u "$USER_NAME" yay -S --sudoloop --noconfirm firefox

# ──────────────────────────────
# Phase 2: Utilities
# ──────────────────────────────
print_header "Utilities Setup"

CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprbw"
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

run_command "pacman -S --noconfirm waybar" "Install Waybar"
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"

sudo -u "$USER_NAME" yay -S --sudoloop --noconfirm tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship
copy_as_user "$REPO_DIR/configs/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# Fastfetch in shells
FASTFETCH_LINE="fastfetch --kitty-direct $USER_HOME/.config/fastfetch/archkitty.png"
for rc in ".bashrc" ".zshrc"; do
  RC_PATH="$USER_HOME/$rc"
  if [ -f "$RC_PATH" ] && ! grep -qF "$FASTFETCH_LINE" "$RC_PATH"; then
    echo -e "\n# Run fastfetch on terminal start\n$FASTFETCH_LINE" >> "$RC_PATH"
    chown "$USER_NAME:$USER_NAME" "$RC_PATH"
  fi
done

run_command "pacman -S --noconfirm cliphist" "Install Cliphist"
copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# Starship config
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
if [ -f "$STARSHIP_SRC" ]; then
  cp "$STARSHIP_SRC" "$STARSHIP_DEST"
  chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
fi
for rc in ".bashrc:bash" ".zshrc:zsh"; do
  shell_rc="${rc%%:*}"
  shell_name="${rc##*:}"
  RC_PATH="$USER_HOME/$shell_rc"
  STARSHIP_LINE="eval \"\$(starship init $shell_name)\""
  if [ -f "$RC_PATH" ] && ! grep -qF "$STARSHIP_LINE" "$RC_PATH"; then
    echo -e "\n$STARSHIP_LINE" >> "$RC_PATH"
    chown "$USER_NAME:$USER_NAME" "$RC_PATH"
  fi
done

# Papirus icons
run_command "pacman -S --noconfirm papirus-icon-theme" "Install Papirus Icon Theme"
if ! command -v papirus-folders &>/dev/null; then
  TMP_DIR=$(mktemp -d)
  git clone https://github.com/PapirusDevelopmentTeam/papirus-folders.git "$TMP_DIR"
  install -Dm755 "$TMP_DIR/papirus-folders" /usr/local/bin/papirus-folders
  rm -rf "$TMP_DIR"
fi
sudo -u "$USER_NAME" dbus-launch papirus-folders -C grey --theme Papirus-Dark

# GTK theming
GTK3_CONFIG_DIR="$USER_HOME/.config/gtk-3.0"
GTK4_CONFIG_DIR="$USER_HOME/.config/gtk-4.0"
mkdir -p "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"
GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name=FlatColor
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono 10"
echo "$GTK_SETTINGS_CONTENT" | sudo -u "$USER_NAME" tee "$GTK3_CONFIG_DIR/settings.ini" "$GTK4_CONFIG_DIR/settings.ini" >/dev/null
chown -R "$USER_NAME:$USER_NAME" "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"
sudo -u "$USER_NAME" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# SDDM theming
MONO_SDDM_REPO="https://github.com/pwyde/monochrome-kde.git"
MONO_THEME_NAME="monochrome"
git clone --depth=1 "$MONO_SDDM_REPO" /tmp/monochrome-kde
cp -r /tmp/monochrome-kde/sddm/themes/$MONO_THEME_NAME /usr/share/sddm/themes/$MONO_THEME_NAME
chown -R root:root /usr/share/sddm/themes/$MONO_THEME_NAME
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=$MONO_THEME_NAME" > /etc/sddm.conf.d/10-theme.conf
rm -rf /tmp/monochrome-kde

# Thunar custom action
UCA_DIR="$CONFIG_DIR/Thunar"
UCA_FILE="$UCA_DIR/uca.xml"
mkdir -p "$UCA_DIR"
chown "$USER_NAME:$USER_NAME" "$UCA_DIR"
chmod 700 "$UCA_DIR"
KITTY_ACTION='<action>
  <icon>utilities-terminal</icon>
  <name>Open Kitty Here</name>
  <command>kitty --directory=%d</command>
  <description>Open kitty terminal in the current folder</description>
  <patterns>*</patterns>
  <directories_only>true</directories_only>
  <startup_notify>true</startup_notify>
</action>'
if [ ! -f "$UCA_FILE" ]; then
  cat > "$UCA_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
$KITTY_ACTION
</actions>
EOF
  chown "$USER_NAME:$USER_NAME" "$UCA_FILE"
else
  if ! grep -q "<name>Open Kitty Here</name>" "$UCA_FILE"; then
    sed -i "/<\/actions>/ i\\
$KITTY_ACTION
" "$UCA_FILE"
    chown "$USER_NAME:$USER_NAME" "$UCA_FILE"
  fi
fi

print_success "\nUtilities setup complete!"

# ──────────────────────────────
# Phase 3: GPU Drivers
# ──────────────────────────────
print_header "GPU Setup"
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

# ──────────────────────────────
# Done
# ──────────────────────────────
print_bold_blue "\n✅ Setup Complete! You can now reboot to apply changes."

