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
TOTAL_STEPS=16
INSTALL_START=$(date +%s)

################################################################################
# HELPER FUNCTIONS
################################################################################

_cols() { tput cols 2>/dev/null || echo 80; }

hr() {
    local cols=$(_cols)
    echo -e "${BBLK}$(printf "%${cols}s" | tr ' ' "─")${RST}"
}

box_line() {
    local ch="$1" left="$2" right="$3"
    local cols=$(_cols)
    echo -e "${BBLK}${left}$(printf "%$((cols - 2))s" | tr ' ' "$ch")${right}${RST}"
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

elapsed() {
    local now=$(date +%s)
    local diff=$(( now - INSTALL_START ))
    printf "%dm %02ds" $(( diff / 60 )) $(( diff % 60 ))
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
    printf "\r\033[K"
}

print_banner() {
    clear
    echo ""
    box_line "─" "╭" "╮"
    echo ""
    center "${BLD}${BCYN}⟁  hyprland${RST}${BLD}${BBLK}  ·  arch linux  ·  2026${RST}"
    echo ""
    center "${DIM}${BBLK}automated desktop environment installer${RST}"
    echo ""
    box_line "─" "╰" "╯"
    echo ""
}

print_phase() {
    STEP=$((STEP + 1))
    local title="$1"
    local pct=$(( STEP * 100 / TOTAL_STEPS ))
    local done_blocks=$(( STEP * 20 / TOTAL_STEPS ))
    local todo_blocks=$(( 20 - done_blocks ))
    local bar="${BMAG}$(printf '%0.s▪' $(seq 1 $done_blocks))${RST}${BBLK}$(printf '%0.s▫' $(seq 1 $todo_blocks))${RST}"

    echo ""
    hr
    printf "  ${bar}  ${BLD}${BWHT}%-32s${RST}  ${BBLK}[${BCYN}%02d${BBLK}/${BCYN}%02d${BBLK}]  %3d%%${RST}\n" \
        "$title" "$STEP" "$TOTAL_STEPS" "$pct"
    echo ""
}

print_ok()     { echo -e "    ${BGRN}✓${RST}  $1"; }
print_err()    { echo -e "\n    ${BRED}✗  ${BLD}$1${RST}\n" >&2; exit 1; }
print_info()   { echo -e "    ${BBLU}◆${RST}  ${DIM}$1${RST}"; }
print_item()   { echo -e "    ${BBLK}•${RST}  $1"; }
print_warn()   { echo -e "    ${BYLW}!${RST}  $1"; }

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
WALLPAPERS_REPO="https://github.com/Saltyfunnel/Wallpapers.git"
DESKTOP_ENTRIES_SRC="$REPO_ROOT/desktop-entries"
LOCALSEND_REPO_API="https://api.github.com/repos/localsend/localsend/releases/latest"
LOCALSEND_DIR="/opt/localsend"

print_banner

[[ "$EUID" -eq 0 ]] || print_err "Run as root  →  sudo $0"

printf "    ${BBLK}%-8s${RST}${WHT}%s${RST}\n" "user" "$USER_NAME"
printf "    ${BBLK}%-8s${RST}${WHT}%s${RST}\n" "home" "$USER_HOME"
printf "    ${BBLK}%-8s${RST}${WHT}%s${RST}\n" "repo" "$REPO_ROOT"
echo ""

echo -e "    ${BYLW}${BLD}⚿  sudo password required${RST}  ${BBLK}(cached for the session)${RST}"
echo ""
read -r -s -p "    $(echo -e "${BCYN}password ›${RST} ")" USER_PASS
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

################################################################################
# PACMAN CONFIGURATION (ILoveCandy, Color, ParallelDownloads)
################################################################################

print_phase "Configuring pacman.conf"

# Enable Color
sed -i 's/^#Color/Color/' /etc/pacman.conf

# Enable ParallelDownloads
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf

# Enable ILoveCandy under [options]
if grep -q "^#ILoveCandy" /etc/pacman.conf; then
    sed -i 's/^#ILoveCandy/ILoveCandy/' /etc/pacman.conf
elif ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi

print_ok "pacman.conf updated (ILoveCandy, Color, ParallelDownloads)"

################################################################################
# SYSTEM UPDATE & DRIVERS
################################################################################

print_phase "System update & driver detection"

run_command "pacman -Syu --noconfirm" "Synchronising package databases"

GPU_INFO=$(lspci | grep -Ei "VGA|3D" || true)

if echo "$GPU_INFO" | grep -qi nvidia; then
    print_item "${BBLK}gpu${RST}  ${BGRN}●${RST}  ${WHT}NVIDIA${RST}"
    run_command "pacman -S --noconfirm --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers" \
        "Installing NVIDIA open-source drivers"
elif echo "$GPU_INFO" | grep -qi amd; then
    print_item "${BBLK}gpu${RST}  ${BRED}●${RST}  ${WHT}AMD${RST}"
    run_command "pacman -S --noconfirm --needed xf86-video-amdgpu mesa vulkan-radeon lib32-vulkan-radeon linux-headers" \
        "Installing AMD drivers & Vulkan support"
elif echo "$GPU_INFO" | grep -qi intel; then
    print_item "${BBLK}gpu${RST}  ${BCYN}●${RST}  ${WHT}Intel${RST}"
    run_command "pacman -Sy --noconfirm" "Syncing repositories"
    run_command "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel linux-headers" \
        "Installing Intel drivers & Vulkan support"
else
    print_item "${BBLK}gpu${RST}  ${BWHT}●${RST}  ${WHT}generic${RST}"
fi

################################################################################
# PACKAGE INSTALLATION
################################################################################

print_phase "Package Installation"

CORE_PACKAGES=(
    hyprland awww mako zed sddm qt6-5compat pacman-contrib
    xdg-desktop-portal-hyprland
)
TERMINAL_PACKAGES=(kitty starship fastfetch)
UTILITY_PACKAGES=(
    grim slurp wl-clipboard polkit-kde-agent
    bluez bluez-utils blueman udiskie udisks2 gvfs networkmanager network-manager-applet
    fuse2 gsettings-desktop-schemas
)
FILE_PACKAGES=(
    thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer file-roller exo
)
APP_PACKAGES=(firefox mpv imv pavucontrol btop gnome-disk-utility steam spotify-launcher qbittorrent libreoffice-fresh gimp)
DEV_PACKAGES=(git base-devel wget curl nano jq python-pipx rust alsa-lib pkgconf ueberzugpp cmake ninja meson wayland wayland-protocols mpv)
FONT_PACKAGES=(ttf-jetbrains-mono-nerd ttf-hack-nerd ttf-iosevka-nerd ttf-cascadia-code-nerd)
MEDIA_PACKAGES=(poppler imagemagick ffmpeg wf-recorder chafa)
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
    printf "  ${BMAG}▎${RST} ${BBLU}%-12s${RST} ${DIM}%s${RST}\n" "$label" "${GROUP_LABELS[$label]}"
done
echo ""

run_command "pacman -S --noconfirm --needed ${ALL_PACKAGES[*]}" \
    "Installing all packages  (${#ALL_PACKAGES[@]} total)"

################################################################################
# WAYBAR-GIT (SOURCE BUILD)
################################################################################

print_phase "waybar-git (source build)"

WAYBAR_BUILD_DEPS=(
    git meson ninja cmake wayland wayland-protocols scdoc gtkmm3 jsoncpp
    libsigc++ fmt spdlog gtk3 glibmm libnl libxkbcommon catch2 systemd
)
run_command "pacman -S --noconfirm --needed ${WAYBAR_BUILD_DEPS[*]}" "Installing waybar build dependencies"

WAYBAR_SRC_TMP="/tmp/waybar-git-src"
rm -rf "$WAYBAR_SRC_TMP"

run_command "sudo -u $USER_NAME git clone --depth 1 https://aur.archlinux.org/waybar-git.git '$WAYBAR_SRC_TMP'" "Cloning waybar-git AUR repository"

(
    cd "$WAYBAR_SRC_TMP"
    sudo -u "$USER_NAME" makepkg -si --noconfirm
) > /tmp/hypr_install_log 2>&1 &

spinner "$!" "Building and installing waybar-git"
wait $! || print_err "waybar-git build failed  →  /tmp/hypr_install_log"

print_ok "waybar-git built and installed successfully"

################################################################################
# PYWAL16 (PIP — NO AUR)
################################################################################

print_phase "pywal16 (pip)"

sudo -u "$USER_NAME" pipx install pywal16 \
    > /tmp/hypr_install_log 2>&1 &
spinner "$!" "Installing pywal16 via pipx"
wait $! || print_err "pywal16 install failed  →  /tmp/hypr_install_log"
print_ok "pywal16 installed via pipx (PyPI, not AUR)"

################################################################################
# LOCALSEND (GITHUB APPIMAGE — NO AUR)
################################################################################

print_phase "LocalSend (GitHub AppImage)"

mkdir -p "$LOCALSEND_DIR"

print_info "Querying latest LocalSend release"
LOCALSEND_URL=$(curl -fsSL "$LOCALSEND_REPO_API" | jq -r '.assets[] | select(.name | test("linux-x86-64\\.AppImage$")) | .browser_download_url')
LOCALSEND_VERSION=$(curl -fsSL "$LOCALSEND_REPO_API" | jq -r '.tag_name')

[[ -n "$LOCALSEND_URL" && "$LOCALSEND_URL" != "null" ]] || print_err "Could not resolve LocalSend AppImage download URL"
print_ok "Resolved latest release  →  $LOCALSEND_VERSION"

run_command "curl -fsSL -o '$LOCALSEND_DIR/LocalSend.AppImage' '$LOCALSEND_URL'" "Downloading LocalSend AppImage"

chmod +x "$LOCALSEND_DIR/LocalSend.AppImage"
ln -sf "$LOCALSEND_DIR/LocalSend.AppImage" /usr/local/bin/localsend
print_ok "LocalSend linked  →  /usr/local/bin/localsend"

# Extract the app icon from the AppImage so the launcher has a proper icon
(
    cd "$LOCALSEND_DIR"
    ./LocalSend.AppImage --appimage-extract >/dev/null 2>&1 || true
    ICON_SRC=$(find squashfs-root -iname "*.png" -o -iname "*.svg" 2>/dev/null | grep -i localsend | head -n1)
    if [[ -n "${ICON_SRC:-}" ]]; then
        mkdir -p /usr/share/icons/hicolor/512x512/apps
        cp "$ICON_SRC" /usr/share/icons/hicolor/512x512/apps/localsend.png 2>/dev/null || true
        gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
    fi
    rm -rf squashfs-root
) > /tmp/hypr_install_log 2>&1 || true
print_ok "LocalSend icon extracted"

cat > /usr/share/applications/localsend.desktop << 'EOF'
[Desktop Entry]
Name=LocalSend
Comment=Share files and messages across your local network
Exec=localsend %U
Icon=localsend
Terminal=false
Type=Application
Categories=Network;FileTransfer;
StartupWMClass=LocalSend
EOF
print_ok "LocalSend desktop entry created  →  $LOCALSEND_VERSION"

################################################################################
# DIRECTORY STRUCTURE
################################################################################

print_phase "Directory Structure"

CONFIG_DIRS=(
    "$CONFIG_DIR/hypr"             "$CONFIG_DIR/waybar"
    "$CONFIG_DIR/kitty"            "$CONFIG_DIR/fastfetch"
    "$CONFIG_DIR/mako"             "$CONFIG_DIR/scripts"
    "$CONFIG_DIR/wal/templates"    "$CONFIG_DIR/btop"
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
sudo -u "$USER_NAME" mkdir -p "$USER_HOME/.local/share/applications"
print_item "${DIM}$USER_HOME/.local/share/applications${RST}"
print_ok "Directory tree created"

################################################################################
# CONFIGURATION FILES
################################################################################

print_phase "Configuration files"

OLD_SYMLINKS=(
    "$CONFIG_DIR/waybar/style.css"
    "$CONFIG_DIR/kitty/kitty.conf"
    "$CONFIG_DIR/mako/config"
    "$CONFIG_DIR/zed/themes/zed.json"
)
for s in "${OLD_SYMLINKS[@]}"; do sudo -u "$USER_NAME" rm -f "$s" 2>/dev/null || true; done
print_ok "Stale symlinks & conflicting files cleared"

[[ -d "$CONFIGS_SRC/hypr"                 ]] && run_command "sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/hypr/'* '$CONFIG_DIR/hypr/'"                                   "Hyprland config"
[[ -d "$CONFIGS_SRC/waybar"               ]] && run_command "sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/waybar/'* '$CONFIG_DIR/waybar/'"                             "Waybar config"
[[ -f "$CONFIGS_SRC/kitty/kitty.conf"      ]] && run_command "sudo -u $USER_NAME cp '$CONFIGS_SRC/kitty/kitty.conf' '$CONFIG_DIR/kitty/kitty.conf'"                "Kitty config"
[[ -f "$CONFIGS_SRC/fastfetch/config.jsonc"  ]] && run_command "sudo -u $USER_NAME cp '$CONFIGS_SRC/fastfetch/config.jsonc' '$CONFIG_DIR/fastfetch/config.jsonc'" "Fastfetch config"
[[ -f "$CONFIGS_SRC/starship/starship.toml"  ]] && run_command "sudo -u $USER_NAME cp '$CONFIGS_SRC/starship/starship.toml' '$CONFIG_DIR/starship.toml'"          "Starship config"
[[ -f "$CONFIGS_SRC/btop/btop.conf"          ]] && run_command "sudo -u $USER_NAME cp '$CONFIGS_SRC/btop/btop.conf' '$CONFIG_DIR/btop/btop.conf'"                  "btop config"
[[ -d "$CONFIGS_SRC/wal/templates"           ]] && run_command "sudo -u $USER_NAME cp -rf '$CONFIGS_SRC/wal/templates/'* '$CONFIG_DIR/wal/templates/'"            "pywal templates"

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

################################################################################
# GPU-SPECIFIC ENVIRONMENT
################################################################################

print_phase "GPU environment"

GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.lua"
sudo -u "$USER_NAME" bash -c "echo '-- GPU environment — auto-generated' > '$GPU_ENV_FILE'"

if echo "$GPU_INFO" | grep -qi nvidia; then
    sudo -u "$USER_NAME" cat >> "$GPU_ENV_FILE" << 'EOF'
return {
  LIBVA_DRIVER_NAME         = "nvidia",
  VDPAU_DRIVER               = "nvidia",
  XDG_SESSION_TYPE          = "wayland",
  __GLX_VENDOR_LIBRARY_NAME = "nvidia",
  GBM_BACKEND               = "nvidia-drm",
  WLR_NO_HARDWARE_CURSORS   = "1",
  __GL_GSYNC_ALLOWED        = "1",
  __GL_VRR_ALLOWED          = "1",
  QT_QPA_PLATFORM           = "wayland",
  MOZ_ENABLE_WAYLAND        = "1",
  GDK_BACKEND               = "wayland",
  XDG_CURRENT_DESKTOP       = "Hyprland",
  XDG_SESSION_DESKTOP       = "Hyprland",
}
EOF
elif echo "$GPU_INFO" | grep -qi amd; then
    sudo -u "$USER_NAME" cat >> "$GPU_ENV_FILE" << 'EOF'
return {
  LIBVA_DRIVER_NAME   = "radeonsi",
  VDPAU_DRIVER        = "radeonsi",
  XDG_SESSION_TYPE    = "wayland",
  QT_QPA_PLATFORM     = "wayland",
  MOZ_ENABLE_WAYLAND  = "1",
  GDK_BACKEND         = "wayland",
  XDG_CURRENT_DESKTOP = "Hyprland",
  XDG_SESSION_DESKTOP = "Hyprland",
}
EOF
elif echo "$GPU_INFO" | grep -qi intel; then
    sudo -u "$USER_NAME" cat >> "$GPU_ENV_FILE" << 'EOF'
return {
  LIBVA_DRIVER_NAME   = "iHD",
  XDG_SESSION_TYPE    = "wayland",
  QT_QPA_PLATFORM     = "wayland",
  MOZ_ENABLE_WAYLAND  = "1",
  GDK_BACKEND         = "wayland",
  XDG_CURRENT_DESKTOP = "Hyprland",
  XDG_SESSION_DESKTOP = "Hyprland",
}
EOF
else
    sudo -u "$USER_NAME" cat >> "$GPU_ENV_FILE" << 'EOF'
return {
  XDG_SESSION_TYPE    = "wayland",
  QT_QPA_PLATFORM     = "wayland",
  MOZ_ENABLE_WAYLAND  = "1",
  GDK_BACKEND         = "wayland",
  XDG_CURRENT_DESKTOP = "Hyprland",
  XDG_SESSION_DESKTOP = "Hyprland",
}
EOF
fi
print_ok "GPU env written  →  hypr/gpu-env.lua"

################################################################################
# SCRIPTS, WALLPAPERS & SHELL
################################################################################

print_phase "Scripts, wallpapers & shell"

[[ -d "$SCRIPTS_SRC" ]] && \
    run_command "sudo -u $USER_NAME cp -rf '$SCRIPTS_SRC/'* '$CONFIG_DIR/scripts/' && chmod +x '$CONFIG_DIR/scripts/'* 2>/dev/null || true" \
    "User scripts"

WALLPAPER_TMP="/tmp/wallpapers-src"
rm -rf "$WALLPAPER_TMP"
run_command "sudo -u $USER_NAME git clone --depth 1 '$WALLPAPERS_REPO' '$WALLPAPER_TMP'" "Cloning Wallpapers repository"
run_command "sudo -u $USER_NAME cp -rf '$WALLPAPER_TMP/'* '$USER_HOME/Pictures/Wallpapers/' && rm -rf '$USER_HOME/Pictures/Wallpapers/.git'" "Deploying Wallpapers"
rm -rf "$WALLPAPER_TMP"

sudo -u "$USER_NAME" cat > "$USER_HOME/.bashrc" << 'EOF'
#!/bin/bash
[[ -f ~/.cache/wal/sequences ]] && cat ~/.cache/wal/sequences
command -v starship >/dev/null && eval "$(starship init bash)"
command -v fastfetch >/dev/null && fastfetch
export PATH="$PATH:$HOME/.local/bin:$HOME/.cargo/bin"
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
# SDDM PYWAL THEME (OPTIONAL)
################################################################################

print_phase "SDDM pywal theme"

read -r -p "    $(echo -e "${BCYN}apply pywal-themed SDDM login screen? [y/N] ›${RST} ")" SDDM_THEME_CHOICE
SDDM_THEME_CHOICE=${SDDM_THEME_CHOICE:-N}

if [[ "$SDDM_THEME_CHOICE" =~ ^[Yy]$ ]]; then
    SDDM_THEME_NAME="pywal-sddm"
    SDDM_THEME_DIR="/usr/share/sddm/themes/${SDDM_THEME_NAME}"
    SDDM_CONF_DIR="/etc/sddm.conf.d"
    SDDM_SETWALL_SCRIPT="$CONFIG_DIR/scripts/setwall.sh"
    SDDM_GLOBAL_WAL_CACHE="/var/cache/wal"

    faillock --user "$USER_NAME" --reset 2>/dev/null || true

    run_command "pacman -S --noconfirm --needed sddm qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects" \
        "Installing SDDM QML dependencies"

    mkdir -p "$SDDM_THEME_DIR"
    mkdir -p "$SDDM_GLOBAL_WAL_CACHE"
    chown -R "$USER_NAME:$USER_NAME" "$SDDM_GLOBAL_WAL_CACHE"
    chmod 755 "$SDDM_GLOBAL_WAL_CACHE"

    if [[ -f "$USER_HOME/.cache/wal/colors.json" ]]; then
        cp "$USER_HOME/.cache/wal/colors.json" "$SDDM_GLOBAL_WAL_CACHE/colors.json"
    else
        echo '{"special":{"background":"#1a1b26","foreground":"#c0caf5"},"colors":{"color0":"#24283b","color4":"#7aa2f7"}}' > "$SDDM_GLOBAL_WAL_CACHE/colors.json"
    fi
    chmod 644 "$SDDM_GLOBAL_WAL_CACHE/colors.json"
    print_ok "Global pywal colour cache seeded  →  $SDDM_GLOBAL_WAL_CACHE/colors.json"

    cat << 'QMLEOF' > "$SDDM_THEME_DIR/Main.qml"
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 1920
    height: 1080

    // Default fallback colors
    property color colorBg: "#1a1b26"
    property color colorFg: "#c0caf5"
    property color colorAccent: "#7aa2f7"
    property color colorInputBg: "#24283b"

    // Global location accessible by sddm user
    readonly property string pywalJsonPath: "file:///var/cache/wal/colors.json"

    function loadWalColors() {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", root.pywalJsonPath, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        var colors = JSON.parse(xhr.responseText);
                        if (colors.special) {
                            root.colorBg = colors.special.background || root.colorBg;
                            root.colorFg = colors.special.foreground || root.colorFg;
                        }
                        if (colors.colors) {
                            root.colorAccent = colors.colors.color4 || root.colorAccent;
                            root.colorInputBg = colors.colors.color0 || root.colorInputBg;
                        }
                    } catch (e) {
                        console.log("Failed to parse pywal JSON, using fallback colors.");
                    }
                }
            }
        };
        xhr.send();
    }

    Component.onCompleted: {
        loadWalColors();
    }

    color: root.colorBg

    // Center Card Container
    Rectangle {
        anchors.centerIn: parent
        width: 360
        height: 380
        radius: 16
        color: Qt.rgba(root.colorInputBg.r, root.colorInputBg.g, root.colorInputBg.b, 0.6)
        border.color: root.colorAccent
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 60

            // User Avatar / Icon Indicator
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: root.colorAccent

                Text {
                    anchors.centerIn: parent
                    text: usernameInput.text.length > 0 ? usernameInput.text.substring(0, 1).toUpperCase() : "?"
                    color: root.colorBg
                    font.pixelSize: 32
                    font.bold: true
                    font.family: "Hack Nerd Font"
                }
            }

            // Username Input Field
            TextField {
                id: usernameInput
                Layout.fillWidth: true
                placeholderText: "Username"
                text: userModel.lastUser
                font.family: "Hack Nerd Font"
                font.pixelSize: 14
                color: root.colorFg
                background: Rectangle {
                    color: Qt.darker(root.colorInputBg, 1.2)
                    radius: 8
                    border.color: usernameInput.activeFocus ? root.colorAccent : "transparent"
                    border.width: 1
                }
            }

            // Password Input Field
            TextField {
                id: passwordInput
                Layout.fillWidth: true
                placeholderText: "Password"
                echoMode: TextInput.Password
                font.family: "Hack Nerd Font"
                font.pixelSize: 14
                color: root.colorFg
                focus: true
                background: Rectangle {
                    color: Qt.darker(root.colorInputBg, 1.2)
                    radius: 8
                    border.color: passwordInput.activeFocus ? root.colorAccent : "transparent"
                    border.width: 1
                }
                onAccepted: sddm.login(usernameInput.text, passwordInput.text, sessionSelect.currentIndex)
            }

            // Session Selector
            ComboBox {
                id: sessionSelect
                Layout.fillWidth: true
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                font.family: "Hack Nerd Font"
                font.pixelSize: 12
            }

            // Login Button
            Button {
                Layout.fillWidth: true
                height: 40
                onClicked: sddm.login(usernameInput.text, passwordInput.text, sessionSelect.currentIndex)

                contentItem: Text {
                    text: "LOGIN"
                    color: root.colorBg
                    font.bold: true
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.down ? Qt.darker(root.colorAccent, 1.2) : root.colorAccent
                    radius: 8
                }
            }
        }
    }
}
QMLEOF
    print_ok "Main.qml written  →  $SDDM_THEME_DIR"

    cat << EOF > "$SDDM_THEME_DIR/metadata.desktop"
[SddmGreeterTheme]
Name=${SDDM_THEME_NAME}
Description=A sleek minimalist theme that imports pywal16 colors dynamically
Author=Custom
Type=sddm-theme
ConfigFile=theme.conf
MainScript=Main.qml
EOF
    print_ok "metadata.desktop written"

    mkdir -p "$SDDM_CONF_DIR"
    cat << EOF > "$SDDM_CONF_DIR/theme.conf"
[Theme]
Current=${SDDM_THEME_NAME}
EOF
    print_ok "SDDM configured to use  →  ${SDDM_THEME_NAME}"

    if [[ -f "$SDDM_SETWALL_SCRIPT" ]]; then
        if ! grep -q "/var/cache/wal/colors.json" "$SDDM_SETWALL_SCRIPT"; then
            sudo -u "$USER_NAME" bash -c "cat >> '$SDDM_SETWALL_SCRIPT' << 'HOOK'

# Sync colors to global cache for SDDM access
if [ -f \"\$HOME/.cache/wal/colors.json\" ]; then
    cp -f \"\$HOME/.cache/wal/colors.json\" /var/cache/wal/colors.json 2>/dev/null || true
    chmod 644 /var/cache/wal/colors.json 2>/dev/null || true
fi
HOOK"
            print_ok "setwall.sh patched with global colour sync hook"
        else
            print_ok "setwall.sh already has the sync hook  →  skipped"
        fi
    else
        print_warn "setwall.sh not found at $SDDM_SETWALL_SCRIPT — skipping patch"
    fi

    print_ok "Pywal SDDM theme installed  →  applies on next SDDM start"
else
    print_item "${DIM}Skipped — default SDDM theme kept${RST}"
fi

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

sudo -u "$USER_NAME" gtk-update-icon-cache -f -t "$USER_HOME/.local/share/icons/Colloid-Dynamic-Dark" >/dev/null 2>&1 || true
print_ok "Icon cache refreshed  →  Colloid-Dynamic-Dark"

sudo -u "$USER_NAME" gsettings set org.gnome.desktop.interface icon-theme 'Colloid-Dynamic-Dark' 2>/dev/null || true
print_ok "gsettings icon-theme set  →  Colloid-Dynamic-Dark"

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

[[ -f "$CONFIG_DIR/wal/templates/waybar-style.css" ]] && \
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/waybar-style.css" "$CONFIG_DIR/waybar/style.css" && \
    print_ok "waybar/style.css"

[[ -f "$CONFIG_DIR/wal/templates/mako-config" ]] && \
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/mako-config" "$CONFIG_DIR/mako/config" && \
    print_ok "mako/config"

[[ -f "$CONFIG_DIR/wal/templates/zed.json" ]] && \
    sudo -u "$USER_NAME" ln -sf "$WAL_CACHE/colors-zed.json" "$CONFIG_DIR/zed/themes/zed.json" && \
    print_ok "zed/themes/zed.json"

################################################################################
# CLEANUP (BUILD ARTIFACTS & TEMP DOWNLOADS)
################################################################################

print_phase "Cleanup"

rm -rf "$WAYBAR_SRC_TMP" 2>/dev/null || true
print_ok "Removed waybar-git build source  →  $WAYBAR_SRC_TMP"

rm -rf "$COLLOID_SRC" 2>/dev/null || true
print_ok "Removed Colloid icon theme source  →  $COLLOID_SRC"

rm -rf "$LOCALSEND_DIR/squashfs-root" 2>/dev/null || true
print_ok "Cleared LocalSend extraction artifacts"

rm -f /tmp/hypr_install_log 2>/dev/null || true
print_ok "Removed install log"

################################################################################
# SERVICES & PERMISSIONS
################################################################################

print_phase "Services & permissions"

systemctl enable sddm.service            2>/dev/null && print_ok "sddm enabled"             || true
systemctl enable bluetooth.service        2>/dev/null && print_ok "bluetooth enabled"         || true
systemctl enable NetworkManager.service 2>/dev/null && print_ok "NetworkManager enabled"    || true

chown -R "$USER_NAME:$USER_NAME" "$CONFIG_DIR" "$CACHE_DIR" "$USER_HOME/Pictures" "$USER_HOME/.local" 2>/dev/null || true
print_ok "Ownership set"

################################################################################
# DONE
################################################################################

clear
print_banner

center "${BLD}${BGRN}✓  installation complete${RST}"
center "${DIM}${BBLK}finished in $(elapsed)${RST}"
echo ""
box_line "─" "╭" "╮"

_row() { printf "${BBLK}│${RST}  ${BGRN}✓${RST}  %-36s${DIM}%-22s${RST}${BBLK}│${RST}\n" "$1" "$2"; }
_row "pacman configured"                    "ILoveCandy, Color, ParallelDl"
_row "system updated"                       "pacman -Syu"
_row "packages + waybar-git"                "pacman & AUR source build"
_row "pywal16"                              "pipx (PyPI, no AUR)"
_row "localsend"                            "GitHub AppImage, no AUR"
_row "dotfiles deployed"                    "~/.config/*"
_row "gpu environment"                      "hypr/gpu-env.lua"
_row "gtk3 & gtk4 dark theme"               "Adwaita-dark"
_row "colloid-dynamic icons"                "~/.local/share/icons"
_row "pywal symlinks"                       "wal → cache"
_row "zed theme"                            "zed/themes/zed.json"
_row "sddm · bluetooth · networkmanager"    "systemctl enable"
_row "sddm pywal theme"                     "if selected"
_row "build artifacts cleaned"              "waybar-git, colloid-src, logs"

box_line "─" "╰" "╯"
echo ""

read -r -p "    $(echo -e "${BCYN}remove installer folder '$REPO_ROOT'? [y/N] ›${RST} ")" CLEAN_REPO_CHOICE
CLEAN_REPO_CHOICE=${CLEAN_REPO_CHOICE:-N}

if [[ "$CLEAN_REPO_CHOICE" =~ ^[Yy]$ ]]; then
    # Deleting the directory a running script lives in is unreliable if done
    # inline, so detach the removal into a background job that fires just
    # after this process exits.
    nohup bash -c "sleep 2; rm -rf '$REPO_ROOT'" >/dev/null 2>&1 &
    disown
    print_ok "Installer folder '$REPO_ROOT' will be removed after this script exits"
fi

echo ""
center "${DIM}${BBLK}reboot when you're ready: ${RST}${BWHT}reboot${RST}"
echo ""
