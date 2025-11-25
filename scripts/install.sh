#!/bin/bash
# Minimal Hyprland Installer with PROPER pywal16 template support
set -euo pipefail

# ----------------------------
# Helper functions
# ----------------------------
print_header() {
    echo -e "\n--- \e[1m\e[34m$1\e[0m ---"
}

print_success() {
    echo -e "\e[32m$1\e[0m"
}

print_warning() {
    echo -e "\e[33mWarning: $1\e[0m" >&2
}

print_error() {
    echo -e "\e[31mError: $1\e[0m" >&2
    exit 1
}

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

# Pywal template directories
WAL_TEMPLATES="$CONFIG_DIR/wal/templates"
WAL_CACHE="$USER_HOME/.cache/wal"

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
    hyprland waybar swww mako grim slurp kitty nano wget jq oculante btop steam
    sddm polkit polkit-kde-agent code curl bluez bluez-utils blueman python-pyqt6 python-pillow
    thunar gvfs gvfs-mtp gvfs-gphoto2 gvfs-smb udisks2 chafa nwg-look papirus-icon-theme
    thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer file-roller
    firefox yazi fastfetch starship mpv gnome-disk-utility pavucontrol
    qt5-wayland qt6-wayland gtk3 gtk4 libgit2
    ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-fira-code ttf-fira-mono ttf-cascadia-code-nerd
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
    localsend-bin
    protonplus
)
for pkg in "${AUR_PACKAGES[@]}"; do
    if yay -Qs "^$pkg$" &>/dev/null; then
        print_success "✅ $pkg is already installed"
    else
        run_command "sudo -u $USER_NAME yay -S --noconfirm $pkg" "Install $pkg from AUR"
    fi
done

# ----------------------------
# Shell Setup (Bash only)
# ----------------------------
print_header "Shell Setup"
run_command "chsh -s $(command -v bash) $USER_NAME" "Set Bash as default shell"

BASHRC_SRC="$REPO_ROOT/configs/.bashrc"
BASHRC_DEST="$USER_HOME/.bashrc"

if [[ -f "$BASHRC_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$BASHRC_SRC" "$BASHRC_DEST"
    print_success ".bashrc copied from repo"
else
    print_warning "No .bashrc found in repo, creating a minimal one"
    cat <<'EOF' | sudo -u "$USER_NAME" tee "$BASHRC_DEST" >/dev/null
# Restore Pywal colors and clear terminal
wal -R -q 2>/dev/null && clear

# Initialize Starship prompt
eval "$(starship init bash)"

# Run fastfetch after login
fastfetch
EOF
    print_success "Minimal .bashrc created with wal + fastfetch + starship"
fi

# ----------------------------
# Copy Hyprland configs
# ----------------------------
print_header "Copying Hyprland configs"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/hypr"
[[ -f "$HYPR_CONFIG_SRC" ]] && sudo -u "$USER_NAME" cp "$HYPR_CONFIG_SRC" "$CONFIG_DIR/hypr/hyprland.conf" && print_success "Copied hyprland.conf"
[[ -f "$COLOR_FILE_SRC" ]] && sudo -u "$USER_NAME" cp "$COLOR_FILE_SRC" "$CONFIG_DIR/hypr/colors-hyprland.conf" && print_success "Copied colors-hyprland.conf"

# Automatically update exec-once to Mako
HYPR_CONF="$CONFIG_DIR/hypr/hyprland.conf"
if [[ -f "$HYPR_CONF" ]]; then
    sed -i 's/exec-once *= *dunst/exec-once = mako/' "$HYPR_CONF"
    print_success "Hyprland exec-once updated to Mako"
fi

# ----------------------------
# Setup Pywal Templates Directory
# ----------------------------
print_header "Setting up Pywal Templates"
sudo -u "$USER_NAME" mkdir -p "$WAL_TEMPLATES"
sudo -u "$USER_NAME" mkdir -p "$WAL_CACHE"
print_success "Created pywal template directories"

# ----------------------------
# Create Waybar Template (NOT the actual config)
# ----------------------------
print_header "Creating Waybar Pywal Template"
WAYBAR_TEMPLATE="$WAL_TEMPLATES/waybar-style.css"

# Copy existing waybar config.json (this doesn't need templating)
if [[ -d "$WAYBAR_CONFIG_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/waybar"
    [[ -f "$WAYBAR_CONFIG_SRC/config" ]] && sudo -u "$USER_NAME" cp "$WAYBAR_CONFIG_SRC/config" "$CONFIG_DIR/waybar/config"
fi

# Create the CSS TEMPLATE (with pywal variables)
cat <<'EOF' | sudo -u "$USER_NAME" tee "$WAYBAR_TEMPLATE" >/dev/null
/* Waybar CSS - Auto-generated by Pywal */
* {{
    font-family: "FiraCode Nerd Font";
    font-size: 13px;
    min-height: 0;
}}

window#waybar {{
    background-color: transparent;
    color: {foreground};
    border: none;
    transition: background-color 0.3s;
}}

.modules-left,
.modules-center,
.modules-right {{
    background-color: transparent;
    border-radius: 0;
    margin: 0;
    padding: 0;
}}

#window,
#clock,
#custom-spotify,
#custom-firefox,
#custom-steam,
#custom-screenshot,
#cpu,
#battery,
#backlight,
#memory,
#network,
#pulseaudio,
#pulseaudio#microphone,
#custom-power,
#tray,
#workspaces {{
    background-color: {background};
    border-radius: 10px;
    margin: 3px;
    padding: 5px 10px;
    transition: all 0.3s ease;
}}

#window {{ color: {color5}; }}
#clock {{ color: {color3}; }}
#cpu {{ color: {color2}; }}
#memory {{ color: {color4}; }}
#network {{ color: {color6}; }}
#pulseaudio {{ color: {color1}; }}
#pulseaudio#microphone {{ color: {color9}; }}
#custom-power {{ color: {color3}; }}
#tray {{ color: {foreground}; }}

#custom-spotify {{ color: {color2}; }}
#custom-firefox {{ color: {color3}; }}
#custom-steam {{ color: {color4}; }}
#custom-screenshot {{ color: {color12}; }}

#custom-spotify:hover {{
    box-shadow: 0 0 8px {color2};
    background-color: {color2};
}}

#custom-firefox:hover {{
    box-shadow: 0 0 8px {color3};
    background-color: {color3};
}}

#custom-steam:hover {{
    box-shadow: 0 0 8px {color4};
    background-color: {color4};
}}

#workspaces button {{
    background-color: transparent;
    color: {color2};
    border: none;
    margin: 0 3px;
    padding: 0 6px;
}}

#clock {{
    color: {color3};
    padding: 3px 6px;
    margin: 3px;
}}



EOF
print_success "Waybar template created"

# ----------------------------
# Create Mako Template
# ----------------------------
print_header "Creating Mako Pywal Template"
MAKO_TEMPLATE="$WAL_TEMPLATES/mako-config"

cat <<'EOF' | sudo -u "$USER_NAME" tee "$MAKO_TEMPLATE" >/dev/null
# Mako Configuration - Auto-generated by Pywal
anchor=top-right
width=350
height=90
margin=10
padding=8
border-size=2
border-radius=10
font=FiraCode Nerd Font 12

text-color={foreground}
background-color={background}
border-color={color2}
default-timeout=5000

[urgency=low]
background-color={background}
text-color={foreground}
default-timeout=3000

[urgency=normal]
background-color={background}
text-color={foreground}
default-timeout=5000

[urgency=critical]
background-color={color9}
text-color={background}
default-timeout=0
EOF
print_success "Mako template created"

# Note: Yazi theme.toml is kept static (not templated) because it contains
# hundreds of file-type specific icon colors that shouldn't change with wallpapers

# Copy Yazi theme file AS-IS (it has its own color scheme for file types)
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/yazi"
YAZI_THEME_SRC="$REPO_ROOT/configs/yazi/theme.toml"
if [[ -f "$YAZI_THEME_SRC" ]]; then
    sudo -u "$USER_NAME" cp "$YAZI_THEME_SRC" "$CONFIG_DIR/yazi/theme.toml"
    print_success "Copied yazi theme.toml (static file with icon colors)"
fi

# Copy other yazi configs
YAZI_FILES=("yazi.toml" "keymap.toml")
for file in "${YAZI_FILES[@]}"; do
    SRC="$REPO_ROOT/configs/yazi/$file"
    DEST="$CONFIG_DIR/yazi/$file"
    [[ -f "$SRC" ]] && sudo -u "$USER_NAME" cp "$SRC" "$DEST" && print_success "Copied $file"
done

# IMPORTANT: Update yazi.toml to use the pywal theme
YAZI_CONFIG="$CONFIG_DIR/yazi/yazi.toml"
if [[ -f "$YAZI_CONFIG" ]]; then
    # Remove hardcoded colors from [mgr], [statusbar], [preview] sections
    # The theme.toml will handle colors
    sed -i '/^\[mgr\]/,/^\[/ { /^fg = /d; /^bg = /d; /^border = /d; /^highlight = /d; }' "$YAZI_CONFIG"
    sed -i '/^\[statusbar\]/,/^\[/ { /^fg = /d; /^bg = /d; }' "$YAZI_CONFIG"
    sed -i '/^\[preview\]/,/^\[/ { /^fg = /d; /^bg = /d; }' "$YAZI_CONFIG"
    print_success "Cleaned hardcoded colors from yazi.toml"
fi

# ----------------------------
# Create Hyprland Colors Template
# ----------------------------
print_header "Creating Hyprland Colors Template"
HYPRLAND_COLORS_TEMPLATE="$WAL_TEMPLATES/colors-hyprland.conf"

cat <<'EOF' | sudo -u "$USER_NAME" tee "$HYPRLAND_COLORS_TEMPLATE" >/dev/null
# Hyprland Colors - Auto-generated by Pywal

$background = rgb({background.strip})
$foreground = rgb({foreground.strip})
$cursor = rgb({cursor.strip})

$color0 = rgb({color0.strip})
$color1 = rgb({color1.strip})
$color2 = rgb({color2.strip})
$color3 = rgb({color3.strip})
$color4 = rgb({color4.strip})
$color5 = rgb({color5.strip})
$color6 = rgb({color6.strip})
$color7 = rgb({color7.strip})
$color8 = rgb({color8.strip})
$color9 = rgb({color9.strip})
$color10 = rgb({color10.strip})
$color11 = rgb({color11.strip})
$color12 = rgb({color12.strip})
$color13 = rgb({color13.strip})
$color14 = rgb({color14.strip})
$color15 = rgb({color15.strip})
EOF
print_success "Hyprland colors template created"

# ----------------------------
# Create Kitty Template
# ----------------------------
print_header "Creating Kitty Pywal Template"
KITTY_TEMPLATE="$WAL_TEMPLATES/kitty.conf"

cat <<'EOF' | sudo -u "$USER_NAME" tee "$KITTY_TEMPLATE" >/dev/null
# Kitty Terminal - Auto-generated by Pywal

# Font Configuration
font_family FiraCode Nerd Font
bold_font FiraCode Nerd Font Bold
italic_font FiraCode Nerd Font Italic
bold_italic_font FiraCode Nerd Font Bold Italic
font_size 13.0
line_spacing 0
letter_spacing 0

# Cursor Effects
cursor_trail 3
cursor_trail_decay 0.1 0.4

# Window Settings
background_opacity 0.9
window_padding_width 10
confirm_os_window_close 0

# Pywal Colors
foreground {foreground}
background {background}
cursor {cursor}

color0 {color0}
color1 {color1}
color2 {color2}
color3 {color3}
color4 {color4}
color5 {color5}
color6 {color6}
color7 {color7}
color8 {color8}
color9 {color9}
color10 {color10}
color11 {color11}
color12 {color12}
color13 {color13}
color14 {color14}
color15 {color15}
EOF
print_success "Kitty template created"

# ----------------------------
# Create Symlinks (The Magic Part!)
# ----------------------------
print_header "Creating Symlinks to Pywal Cache"

# Waybar CSS symlink
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css"
print_success "Waybar CSS → Pywal cache"

# Mako config symlink
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/mako"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config"
print_success "Mako config → Pywal cache"

# Note: Yazi theme.toml is NOT symlinked - it's a static file with file-type icon colors

# Kitty config symlink
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/kitty"
sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/kitty.conf" "$CONFIG_DIR/kitty/kitty.conf"
print_success "Kitty config → Pywal cache"

# ----------------------------
# Copy user scripts
# ----------------------------
print_header "Copying user scripts"
if [[ -d "$SCRIPTS_SRC" ]]; then
    sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/scripts"
    sudo -u "$USER_NAME" cp -rf "$SCRIPTS_SRC/." "$CONFIG_DIR/scripts/"
    sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/"*.sh
    [[ -f "$CONFIG_DIR/scripts/wallpaper-picker.py" ]] && sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/wallpaper-picker.py"
    [[ -f "$CONFIG_DIR/scripts/app-picker.py" ]] && sudo -u "$USER_NAME" chmod +x "$CONFIG_DIR/scripts/app-picker.py"
    print_success "User scripts copied"
fi

# ----------------------------
# Create Screenshots folder
# ----------------------------
print_header "Creating Screenshots Folder"
SCREENSHOT_DIR="$USER_HOME/Pictures/Screenshots"
sudo -u "$USER_NAME" mkdir -p "$SCREENSHOT_DIR"
print_success "Screenshots folder created"

# ----------------------------
# Copy Fastfetch config
# ----------------------------
print_header "Copying Fastfetch config"
sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/fastfetch"
[[ -f "$FASTFETCH_SRC" ]] && sudo -u "$USER_NAME" cp "$FASTFETCH_SRC" "$CONFIG_DIR/fastfetch/config.jsonc" && print_success "Fastfetch config copied"

# ----------------------------
# Copy Starship config
# ----------------------------
print_header "Copying Starship config"
STARSHIP_SRC="$REPO_ROOT/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"
[[ -f "$STARSHIP_SRC" ]] && sudo -u "$USER_NAME" cp "$STARSHIP_SRC" "$STARSHIP_DEST" && print_success "Starship config copied"

# ----------------------------
# Copy Wallpapers
# ----------------------------
print_header "Copying Wallpapers"
WALLPAPER_SRC="$REPO_ROOT/Pictures/Wallpapers"
PICTURES_DEST="$USER_HOME/Pictures"
[[ -d "$WALLPAPER_SRC" ]] && sudo -u "$USER_NAME" mkdir -p "$PICTURES_DEST" && sudo -u "$USER_NAME" cp -rf "$WALLPAPER_SRC" "$PICTURES_DEST/" && print_success "Wallpapers copied"

# ----------------------------
# Enable SDDM
# ----------------------------
print_header "Setting up SDDM"
run_command "systemctl enable sddm.service" "Enable SDDM login manager"

# ----------------------------
# Final message
# ----------------------------
print_success "✅ Installation complete!"
echo -e "\nPywal Template System Setup Complete!"
echo -e "Templates created in: ~/.config/wal/templates/"
echo -e "Configs symlinked to: ~/.cache/wal/"
echo -e "\nRun 'setwall.sh' to generate your first theme!"
echo -e "You can now log out and select the Hyprland session in SDDM."
