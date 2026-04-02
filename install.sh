#!/bin/bash
################################################################################
# Hyprland Installer - 2026 Edition
# Unified installer for AMD/Nvidia/Intel GPUs with automatic configuration
################################################################################

set -euo pipefail

################################################################################
# COLORS & STYLES
################################################################################

RST="\e[0m"
BLK="\e[30m"; RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"
BLU="\e[34m"; MAG="\e[35m"; CYN="\e[36m"; WHT="\e[37m"
BBLK="\e[90m"; BRED="\e[91m"; BGRN="\e[92m"; BYLW="\e[93m"
BBLU="\e[94m"; BMAG="\e[95m"; BCYN="\e[96m"; BWHT="\e[97m"
BLD="\e[1m"; DIM="\e[2m"; ITL="\e[3m"; UND="\e[4m"

STEP=0
TOTAL_STEPS=10

################################################################################
# HELPER FUNCTIONS
################################################################################

_cols() { tput cols 2>/dev/null || echo 80; }

hr() {
    local cols=$(_cols)
    echo -e "${BBLK}$(printf "%${cols}s" | tr ' ' "─")${RST}"
}

center() {
    local text="$1"
    local raw; raw=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#raw}
    local cols=$(_cols)
    local pad=$(( (cols - len) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    printf "%${pad}s" ""
    echo -e "$text"
}

spinner() {
    local pid=$1 msg="$2"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r    ${BCYN}${frames[$i]}${RST}  ${DIM}${msg}${RST}  "
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.07
    done
    tput cnorm 2>/dev/null || true
    printf "\r"
}

print_banner() {
    clear
    echo ""
    echo ""
    center "${BLD}${BCYN}hyprland${RST}${BLD}${BBLK} · arch linux · 2026${RST}"
    echo ""
    center "${DIM}${BBLK}automated desktop environment installer${RST}"
    echo ""
    echo ""
    hr
    echo ""
}

print_phase() {
    STEP=$((STEP + 1))
    local title="$1"
    local pct=$(( STEP * 100 / TOTAL_STEPS ))
    local done_blocks=$(( STEP * 20 / TOTAL_STEPS ))
    local todo_blocks=$(( 20 - done_blocks ))
    local bar="${BCYN}$(printf '%0.s▪' $(seq 1 $done_blocks))${RST}${BBLK}$(printf '%0.s▫' $(seq 1 $todo_blocks))${RST}"

    echo ""
    echo -e "  ${bar}  ${BLD}${BWHT}${title}${RST}  ${BBLK}${pct}%${RST}"
    echo ""
}

print_ok()      { echo -e "    ${BGRN}✓${RST}  $1"; }
print_err()     { echo -e "\n    ${BRED}✗  ${BLD}$1${RST}\n" >&2; exit 1; }
print_info()    { echo -e "    ${BBLK}↳${RST}  ${DIM}$1${RST}"; }
print_item()    { echo -e "    ${BBLK}•${RST}  $1"; }

run_command() {
    local cmd="$1" desc="$2"
    print_info "$desc"
    eval "$cmd" > /tmp/hypr_install_log 2>&1 &
    local pid=$!
    spinner "$pid" "$desc"
    wait "$pid" || print_err "Failed: $desc  →  /tmp/hypr_install_log"
    print_ok "$desc"
}

################################################################################
# CONFIGURATION
################################################################################

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="$USER_HOME/.config"
CACHE_DIR="$USER_HOME/.cache"
WAL_CACHE="$CACHE_DIR/wal"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_SRC="$REPO_ROOT/scripts"
CONFIGS_SRC="$REPO_ROOT/configs"
WALLPAPERS_SRC="$REPO_ROOT/Pictures/Wallpapers"

print_banner

[[ "$EUID" -eq 0 ]] || print_err "Run as root  →  sudo $0"

echo -e "    ${BBLK}user${RST}    ${WHT}${USER_NAME}${RST}"
echo -e "    ${BBLK}home${RST}    ${WHT}${USER_HOME}${RST}"
echo -e "    ${BBLK}repo${RST}    ${WHT}${REPO_ROOT}${RST}"
echo ""

echo -e "    ${BYLW}${BLD}sudo password required${RST}  ${BBLK}(cached for the session)${RST}"
echo ""
read -r -s -p "    $(echo -e "${BCYN}password:${RST} ")" USER_PASS
echo ""

if ! echo "$USER_PASS" | su -c "true" "$USER_NAME" 2>/dev/null; then
    print_err "Incorrect password"
fi

SUDOERS_TMP="/etc/sudoers.d/hypr-install-tmp"
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_TMP"
chmod 0440 "$SUDOERS_TMP"
trap 'rm -f "$SUDOERS_TMP"; echo ""' EXIT

echo ""
print_ok "Credentials accepted"
echo ""
hr

################################################################################
# SYSTEM UPDATE & DRIVERS
################################################################################

print_phase "System update & driver detection"

run_command "pacman -Syu --noconfirm" "Synchronising package databases"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    echo -e "    ${BBLK}gpu${RST}    ${WHT}NVIDIA${RST}"
    run_command "pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" \
        "Installing NVIDIA open-source drivers"
elif echo "$GPU_INFO" | grep -qi amd; then
    echo -e "    ${BBLK}gpu${RST}    ${WHT}AMD${RST}"
    run_command "pacman -S --noconfirm --needed xf86-video-amdgpu mesa vulkan-radeon lib32-vulkan-radeon linux-headers" \
        "Installing AMD drivers & Vulkan support"
elif echo "$GPU_INFO" | grep -qi intel; then
    echo -e "    ${BBLK}gpu${RST}    ${WHT}Intel${RST}"
    run_command "pacman -S --noconfirm --needed mesa vulkan-intel lib32-vulkan-intel linux-headers" \
        "Installing Intel drivers & Vulkan support"
else
    echo -e "    ${BBLK}gpu${RST}    ${WHT}generic${RST}"
fi

################################################################################
# PACKAGE INSTALLATION
################################################################################

print_phase "Package Installation"

CORE_PACKAGES=(
    hyprland waybar awww mako zed ly
    xdg-desktop-portal-hyprland
)
TERMINAL_PACKAGES=(kitty starship fastfetch)
UTILITY_PACKAGES=(
    grim slurp wl-clipboard polkit-kde-agent
    bluez bluez-utils blueman udiskie udisks2 gvfs networkmanager
)
FILE_PACKAGES=(
    thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer file-roller exo
)
APP_PACKAGES=(firefox mpv imv pavucontrol btop gnome-disk-utility)
DEV_PACKAGES=(git base-devel wget curl nano jq)
FONT_PACKAGES=(ttf-jetbrains-mono-nerd ttf-hack-nerd ttf-iosevka-nerd ttf-cascadia-code-nerd)
MEDIA_PACKAGES=(poppler imagemagick ffmpeg chafa)
COMPRESSION_PACKAGES=(unzip p7zip tar gzip xz bzip2 unrar trash-cli)
PYTHON_PACKAGES=(python-pyqt5 python-pyqt6 python-pillow python-opencv)
QT_PACKAGES=(qt5-wayland qt6-wayland)

ALL_PACKAGES=(
    "${CORE_PACKAGES[@]}" "${TERMINAL_PACKAGES[@]}" "${UTILITY_PACKAGES[@]}"
    "${FILE_PACKAGES[@]}" "${APP_PACKAGES[@]}" "${DEV_PACKAGES[@]}"
    "${FONT_PACKAGES[@]}" "${MEDIA_PACKAGES[@]}" "${COMPRESSION_PACKAGES[@]}"
    "${PYTHON_PACKAGES[@]}" "${QT_PACKAGES[@]}"
)

echo ""
declare -A GROUP_LABELS=(
    ["Core WM"]="${CORE_PACKAGES[*]}"
    ["Terminal"]="${TERMINAL_PACKAGES[*]}"
    ["Utilities"]="${UTILITY_PACKAGES[*]}"
    ["Files"]="${FILE_PACKAGES[*]}"
    ["Apps"]="${APP_PACKAGES[*]}"
    ["Dev Tools"]="${DEV_PACKAGES[*]}"
    ["Fonts"]="${FONT_PACKAGES[*]}"
    ["Media"]="${MEDIA_PACKAGES[*]}"
    ["Archives"]="${COMPRESSION_PACKAGES[*]}"
    ["Python"]="${PYTHON_PACKAGES[*]}"
    ["Qt/Wayland"]="${QT_PACKAGES[*]}"
)

for label in "Core WM" "Terminal" "Utilities" "Files" "Apps" "Dev Tools" "Fonts" "Media" "Archives" "Python" "Qt/Wayland"; do
    echo -e "  ${BBLU}${label}${RST}  ${DIM}${GROUP_LABELS[$label]}${RST}"
done
echo ""

run_command "pacman -S --noconfirm --needed ${ALL_PACKAGES[*]}" \
    "Installing all packages  (${#ALL_PACKAGES[@]} total)"

################################################################################
# AUR HELPER & PACKAGES
################################################################################

print_phase "AUR packages"

if ! command -v yay &>/dev/null; then
    run_command "rm -rf /tmp/yay" "Cleaning build directory"
    run_command "sudo -u $USER_NAME git clone https://aur.archlinux.org/yay.git /tmp/yay" \
        "Cloning yay"
    (cd /tmp/yay && sudo -u "$USER_NAME" makepkg -si --noconfirm) \
        > /tmp/hypr_install_log 2>&1 &
    spinner "$!" "Compiling yay"
    wait $! || print_err "Yay build failed  →  /tmp/hypr_install_log"
    print_ok "yay installed"
else
    print_ok "yay already present"
fi

sudo -u "$USER_NAME" yay -S --noconfirm python-pywal16 python-pywalfox \
    > /tmp/hypr_install_log 2>&1 &
spinner "$!" "Installing pywal16, pywalfox"
wait $! || print_err "AUR install failed  →  /tmp/hypr_install_log"
print_ok "AUR packages installed"

################################################################################
# DIRECTORY STRUCTURE
################################################################################

print_phase "Directory Structure"

CONFIG_DIRS=(
    "$CONFIG_DIR/hypr"    "$CONFIG_DIR/waybar"
    "$CONFIG_DIR/kitty"   "$CONFIG_DIR/fastfetch"
    "$CONFIG_DIR/mako"    "$CONFIG_DIR/scripts"
    "$CONFIG_DIR/wal/templates"  "$CONFIG_DIR/btop"
    "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"
    "$CONFIG_DIR/zed/themes"
)

for dir in "${CONFIG_DIRS[@]}"; do
    sudo -u "$USER_NAME" mkdir -p "$dir"
    print_item "${DIM}$dir${RST}"
done

sudo -u "$USER_NAME" mkdir -p "$WAL_CACHE"
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/Pictures/Wallpapers"
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.local/share/icons"
print_ok "Directory tree created"

################################################################################
# CONFIGURATION FILES
################################################################################

print_phase "Configuration files"

OLD_SYMLINKS=(
    "$CONFIG_DIR/waybar/style.css"
    "$CONFIG_DIR/kitty/kitty.conf"
    "$CONFIG_DIR/hypr/colors-hyprland.conf"
    "$CONFIG_DIR/mako/config"
    "$CONFIG_DIR/zed/themes/zed.json"
)
for s in "${OLD_SYMLINKS[@]}"; do sudo -u "$USER_NAME" rm -f "$s" 2>/dev/null || true; done
print_ok "Stale symlinks & conflicting files cleared"

[[ -d "$CONFIGS_SRC/hypr"                   ]] && run_command "sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/hypr/'* '$CONFIG_DIR/hypr/'"                               "Hyprland config"
[[ -d "$CONFIGS_SRC/waybar"                  ]] && run_command "sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/waybar/'* '$CONFIG_DIR/waybar/'"                          "Waybar config"
[[ -f "$CONFIGS_SRC/kitty/kitty.conf"        ]] && run_command "sudo -u $USER_NAME cp '$CONFIGS_SRC/kitty/kitty.conf' '$CONFIG_DIR/kitty/kitty.conf'"             "Kitty config"
[[ -f "$CONFIGS_SRC/fastfetch/config.jsonc"  ]] && run_command "sudo -u $USER_NAME cp '$CONFIGS_SRC/fastfetch/config.jsonc' '$CONFIG_DIR/fastfetch/config.jsonc'" "Fastfetch config"
[[ -f "$CONFIGS_SRC/starship/starship.toml"  ]] && run_command "sudo -u $USER_NAME cp '$CONFIGS_SRC/starship/starship.toml' '$CONFIG_DIR/starship.toml'"          "Starship config"
[[ -f "$CONFIGS_SRC/btop/btop.conf"          ]] && run_command "sudo -u $USER_NAME cp '$CONFIGS_SRC/btop/btop.conf' '$CONFIG_DIR/btop/btop.conf'"                "btop config"
[[ -d "$CONFIGS_SRC/wal/templates"           ]] && run_command "sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/wal/templates/'* '$CONFIG_DIR/wal/templates/'"           "pywal templates"

# mako/config is intentionally NOT copied — managed by pywal symlink

# GTK dark theme
sudo -u "$USER_NAME" bash -c "cat > '$CONFIG_DIR/gtk-3.0/settings.ini' << 'EOF'
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF"
print_ok "GTK3 dark theme configured"

sudo -u "$USER_NAME" bash -c "cat > '$CONFIG_DIR/gtk-4.0/settings.ini' << 'EOF'
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF"
print_ok "GTK4 dark theme configured"

if [[ ! -f "$CONFIGS_SRC/kitty/kitty.conf" ]]; then
    sudo -u "$USER_NAME" cat > "$CONFIG_DIR/kitty/kitty.conf" << 'EOF'
font_family      JetBrainsMono Nerd Font
font_size        11.0
window_padding_width 8
confirm_os_window_close 0
enable_audio_bell no
tab_bar_edge bottom
tab_bar_style powerline
tab_powerline_style slanted
repaint_delay 10
input_delay 3
sync_to_monitor yes
include ~/.cache/wal/kitty-wal.conf
EOF
    print_ok "Default kitty config written"
fi

################################################################################
# GPU-SPECIFIC ENVIRONMENT
################################################################################

print_phase "GPU environment"

GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.conf"
sudo -u "$USER_NAME" bash -c "echo '# GPU environment — auto-generated' > '$GPU_ENV_FILE'"

if echo "$GPU_INFO" | grep -qi nvidia; then
    sudo -u "$USER_NAME" cat >> "$GPU_ENV_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = GBM_BACKEND,nvidia-drm
env = WLR_NO_HARDWARE_CURSORS,1
env = __GL_GSYNC_ALLOWED,1
env = __GL_VRR_ALLOWED,1
env = QT_QPA_PLATFORM,wayland
cursor { no_hardware_cursors = true }
EOF
elif echo "$GPU_INFO" | grep -qi amd; then
    sudo -u "$USER_NAME" cat >> "$GPU_ENV_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,radeonsi
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
EOF
elif echo "$GPU_INFO" | grep -qi intel; then
    sudo -u "$USER_NAME" cat >> "$GPU_ENV_FILE" << 'EOF'
env = LIBVA_DRIVER_NAME,iHD
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
EOF
else
    sudo -u "$USER_NAME" cat >> "$GPU_ENV_FILE" << 'EOF'
env = XDG_SESSION_TYPE,wayland
env = QT_QPA_PLATFORM,wayland
EOF
fi
print_ok "GPU env written  →  hypr/gpu-env.conf"

################################################################################
# SCRIPTS, WALLPAPERS & SHELL
################################################################################

print_phase "Scripts, wallpapers & shell"

[[ -d "$SCRIPTS_SRC" ]] && \
    run_command "sudo -u $USER_NAME cp -rf '$SCRIPTS_SRC/'* '$CONFIG_DIR/scripts/' && chmod +x '$CONFIG_DIR/scripts/'* 2>/dev/null || true" \
    "User scripts"

[[ -d "$WALLPAPERS_SRC" ]] && \
    run_command "sudo -u $USER_NAME cp -rf '$WALLPAPERS_SRC/'* '$USER_HOME/Pictures/Wallpapers/'" \
    "Wallpapers"

sudo -u "$USER_NAME" cat > "$USER_HOME/.bashrc" << 'EOF'
#!/bin/bash
[[ -f ~/.cache/wal/sequences ]] && cat ~/.cache/wal/sequences
command -v starship >/dev/null && eval "$(starship init bash)"
command -v fastfetch >/dev/null && fastfetch
alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo pacman -Syu'
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -i'
EOF
print_ok "Shell configured"

################################################################################
# COLLOID ICON THEME
################################################################################

print_phase "Colloid icon theme"

COLLOID_SRC="$CONFIG_DIR/colloid-src"
if [ ! -d "$COLLOID_SRC" ]; then
    run_command "sudo -u $USER_NAME git clone --depth 1 https://github.com/Saltyfunnel/colloid.git '$COLLOID_SRC'" \
        "Cloning Colloid icon theme"
fi

(cd "$COLLOID_SRC" && sudo -u "$USER_NAME" ./install.sh \
    -d "$USER_HOME/.local/share/icons" \
    -n Colloid-Dynamic \
    -s default) \
    > /tmp/hypr_install_log 2>&1 &
spinner "$!" "Installing Colloid-Dynamic icons"
wait $! || print_err "Colloid install failed  →  /tmp/hypr_install_log"
print_ok "Colloid-Dynamic icons installed"

################################################################################
# THUNAR CUSTOM ACTIONS (KITTY)
################################################################################

print_phase "Thunar Custom Actions"

sudo -u "$USER_NAME" mkdir -p "$CONFIG_DIR/Thunar"

sudo -u "$USER_NAME" bash -c "cat > '$CONFIG_DIR/Thunar/uca.xml' << 'EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<actions>
<action>
    <icon>kitty</icon>
    <name>Open Kitty Here</name>
    <unique-id>kitty-open-here</unique-id>
    <command>kitty --directory %f</command>
    <description>Open Kitty terminal in this directory</description>
    <patterns>*</patterns>
    <directories/>
</action>
</actions>
EOF"

print_ok "Thunar 'Open Kitty Here' action configured"

################################################################################
# PYWAL SYMLINKS
################################################################################

print_phase "Pywal symlinks"

[[ -f "$CONFIG_DIR/wal/templates/waybar-style.css"     ]] && \
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css"     "$CONFIG_DIR/waybar/style.css"          && \
    print_ok "waybar/style.css"

[[ -f "$CONFIG_DIR/wal/templates/colors-hyprland.conf" ]] && \
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-hyprland.conf" "$CONFIG_DIR/hypr/colors-hyprland.conf" && \
    print_ok "hypr/colors-hyprland.conf"

[[ -f "$CONFIG_DIR/wal/templates/mako-config"          ]] && \
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config"          "$CONFIG_DIR/mako/config"               && \
    print_ok "mako/config"

[[ -f "$CONFIG_DIR/wal/templates/zed.json"             ]] && \
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-zed.json"      "$CONFIG_DIR/zed/themes/zed.json"       && \
    print_ok "zed/themes/zed.json"

################################################################################
# SERVICES & PERMISSIONS
################################################################################

print_phase "Services & permissions"

systemctl enable ly@tty2.service        2>/dev/null && print_ok "ly enabled"             || true
systemctl enable bluetooth.service      2>/dev/null && print_ok "bluetooth enabled"      || true
systemctl enable NetworkManager.service 2>/dev/null && print_ok "NetworkManager enabled" || true

chown -R "$USER_NAME:$USER_NAME" "$CONFIG_DIR" "$CACHE_DIR" "$USER_HOME/Pictures" "$USER_HOME/.local" 2>/dev/null || true
print_ok "Ownership set"

################################################################################
# DONE
################################################################################

clear
print_banner

center "${BLD}${BGRN}installation complete${RST}"
echo ""
echo ""

_row() { printf "    ${BGRN}✓${RST}  %-36s${DIM}%s${RST}\n" "$1" "$2"; }
_row "system updated"                        "pacman -Syu"
_row "${#ALL_PACKAGES[@]} packages"          "pacman"
_row "yay · pywal16 · pywalfox"             "AUR"
_row "dotfiles deployed"                     "~/.config/*"
_row "gpu environment"                       "hypr/gpu-env.conf"
_row "gtk3 & gtk4 dark theme"               "Adwaita-dark"
_row "colloid-dynamic icons"                 "~/.local/share/icons"
_row "pywal symlinks"                        "wal → cache"
_row "zed theme"                             "zed/themes/zed.json"
_row "ly · bluetooth · NetworkManager"      "systemctl enable"

echo ""
hr
echo ""

echo -e "    ${BLD}next${RST}"
echo ""
echo -e "    ${BCYN}1${RST}  ${DIM}reboot${RST}                    ${BBLK}sudo reboot${RST}"
echo -e "    ${BCYN}2${RST}  ${DIM}select session at ly${RST}       ${BBLK}Hyprland${RST}"
echo -e "    ${BCYN}3${RST}  ${DIM}set your wallpaper${RST}         ${BBLK}wal -i ~/Pictures/Wallpapers/<img>${RST}"

echo ""
hr
echo ""

_bind() { printf "    ${BBLK}%-22s${RST}${DIM}%s${RST}\n" "$1" "$2"; }
echo -e "    ${BLD}bindings${RST}"
echo ""
_bind "super + return"        "terminal"
_bind "super + d"             "launcher"
_bind "super + q"             "close window"
_bind "super + f"             "file manager"
_bind "super + w"             "wallpaper picker"
_bind "super + b / c / i"    "browser · editor · monitor"
_bind "super + v"             "toggle float"
_bind "super + h/j/k/l"      "focus ← ↓ ↑ →"
_bind "super + [1–5]"         "switch workspace"
_bind "super+shift + [1–5]"  "move to workspace"

echo ""
hr
echo ""
center "${DIM}${BBLK}happy ricing${RST}"
echo ""
