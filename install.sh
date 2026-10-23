#!/bin/bash
################################################################################
# Hyprland Installer - 2026 Edition
# Unified installer for AMD/Nvidia/Intel GPUs with automatic configuration
################################################################################

set -Eeuo pipefail

################################################################################
# COLORS & STYLES
################################################################################

RST="\e[0m"
RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"
WHT="\e[37m"
BBLK="\e[90m"; BRED="\e[91m"; BGRN="\e[92m"; BYLW="\e[93m"
BBLU="\e[94m"; BCYN="\e[96m"; BWHT="\e[97m"
BLD="\e[1m"; DIM="\e[2m"

STEP=0
TOTAL_STEPS=13

LOG_DIR="/tmp/hypr-install-logs"
mkdir -p "$LOG_DIR"

################################################################################
# HELPER FUNCTIONS
################################################################################

_cols() { tput cols 2>/dev/null || echo 80; }

# repeat <char> <count>  (safe when count is 0 or negative)
repeat() {
    local ch="$1" n="$2" out=""
    local i
    for (( i = 0; i < n; i++ )); do out+="$ch"; done
    printf '%s' "$out"
}

hr() {
    local cols; cols=$(_cols)
    echo -e "${BBLK}$(repeat '─' "$cols")${RST}"
}

center() {
    local text="$1"
    local raw; raw=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local len=${#raw}
    local cols; cols=$(_cols)
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
    [[ $pct -gt 100 ]] && pct=100
    local done_blocks=$(( STEP * 20 / TOTAL_STEPS ))
    [[ $done_blocks -gt 20 ]] && done_blocks=20
    local todo_blocks=$(( 20 - done_blocks ))
    local bar="${BCYN}$(repeat '▪' "$done_blocks")${RST}${BBLK}$(repeat '▫' "$todo_blocks")${RST}"

    echo ""
    echo -e "  ${bar}  ${BLD}${BWHT}${title}${RST}  ${BBLK}${pct}%${RST}"
    echo ""
}

print_ok()     { echo -e "    ${BGRN}✓${RST}  $1"; }
print_warn()   { echo -e "    ${BYLW}!${RST}  $1"; }
print_info()   { echo -e "    ${BBLK}↳${RST}  ${DIM}$1${RST}"; }
print_item()   { echo -e "    ${BBLK}•${RST}  $1"; }
print_err()    { echo -e "\n    ${BRED}✗  ${BLD}$1${RST}\n" >&2; exit 1; }

# Run a command as the target (non-root) user with their HOME set properly.
as_user() { sudo -u "$USER_NAME" -H "$@"; }

# Back up a file once before we overwrite it.
backup_file() {
    if [[ -f "$1" && ! -f "$1.pre-install.bak" ]]; then
        cp -a "$1" "$1.pre-install.bak"
    fi
    return 0
}

# Each step gets its own log file so later steps never overwrite an earlier error.
run_command() {
    local cmd="$1" desc="$2"
    local slug; slug=$(echo "$desc" | tr -c 'a-zA-Z0-9\n' '_' | cut -c1-60)
    local log="$LOG_DIR/${slug}.log"

    print_info "$desc"
    eval "$cmd" > "$log" 2>&1 &
    local pid=$!
    spinner "$pid" "$desc"
    if ! wait "$pid"; then
        echo -e "\n    ${BRED}Last lines of log:${RST}" >&2
        tail -n 15 "$log" | sed 's/^/      /' >&2
        print_err "Failed: $desc  →  $log"
    fi
    print_ok "$desc"
}

cleanup() {
    tput cnorm 2>/dev/null || true
    echo ""
}
trap cleanup EXIT
trap 'echo -e "\n    ${BRED}✗  Error on line $LINENO${RST}" >&2' ERR

################################################################################
# PRE-FLIGHT CHECKS
################################################################################

[[ "$EUID" -eq 0 ]] || { echo "Run as root  →  sudo $0" >&2; exit 1; }
[[ -f /etc/arch-release ]] || { echo "This installer is for Arch Linux only." >&2; exit 1; }

USER_NAME="${SUDO_USER:-}"
if [[ -z "$USER_NAME" || "$USER_NAME" == "root" ]]; then
    echo "Run with sudo from your normal user account (not a root login)." >&2
    exit 1
fi
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
[[ -d "$USER_HOME" ]] || { echo "Home directory for $USER_NAME not found." >&2; exit 1; }

CONFIG_DIR="$USER_HOME/.config"
CACHE_DIR="$USER_HOME/.cache"
WAL_CACHE="$CACHE_DIR/wal"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_SRC="$REPO_ROOT/scripts"
CONFIGS_SRC="$REPO_ROOT/configs"
WALLPAPERS_REPO="https://github.com/Saltyfunnel/Wallpapers.git"

print_banner

echo -e "    ${BBLK}user${RST}    ${WHT}${USER_NAME}${RST}"
echo -e "    ${BBLK}home${RST}    ${WHT}${USER_HOME}${RST}"
echo -e "    ${BBLK}repo${RST}    ${WHT}${REPO_ROOT}${RST}"
echo -e "    ${BBLK}logs${RST}    ${WHT}${LOG_DIR}${RST}"
echo ""

if ! curl -fsS --max-time 10 -o /dev/null https://archlinux.org; then
    print_err "No network connection (could not reach archlinux.org)"
fi
print_ok "Network reachable"
echo ""
hr

################################################################################
# PACMAN CONFIGURATION (multilib, ILoveCandy, Color, ParallelDownloads)
################################################################################

print_phase "Configuring pacman.conf"

sed -i 's/^#Color/Color/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf

if grep -q "^#ILoveCandy" /etc/pacman.conf; then
    sed -i 's/^#ILoveCandy/ILoveCandy/' /etc/pacman.conf
elif ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    sed -i '/^\[options\]/a ILoveCandy' /etc/pacman.conf
fi

# Enable [multilib] (needed for steam and lib32-* packages). No-op if already on.
sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
grep -q '^\[multilib\]' /etc/pacman.conf || print_err "Could not enable [multilib] in /etc/pacman.conf"

print_ok "pacman.conf updated (multilib, ILoveCandy, Color, ParallelDownloads)"

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
    run_command "pacman -S --noconfirm --needed mesa vulkan-radeon lib32-vulkan-radeon linux-headers" \
        "Installing AMD drivers & Vulkan support"
elif echo "$GPU_INFO" | grep -qi intel; then
    echo -e "    ${BBLK}gpu${RST}    ${WHT}Intel${RST}"
    run_command "pacman -S --noconfirm --needed mesa lib32-mesa vulkan-intel lib32-vulkan-intel linux-headers" \
        "Installing Intel drivers & Vulkan support"
else
    echo -e "    ${BBLK}gpu${RST}    ${WHT}generic${RST}"
fi

################################################################################
# PACKAGE INSTALLATION
################################################################################

print_phase "Package Installation"

CORE_PACKAGES=(
    hyprland waybar hyprpaper mako zed sddm qt6-5compat pacman-contrib
    xdg-desktop-portal-hyprland
)
TERMINAL_PACKAGES=(kitty starship fastfetch fish cava)
UTILITY_PACKAGES=(
    grim slurp wl-clipboard polkit-kde-agent
    bluez bluez-utils blueman udiskie udisks2 gvfs networkmanager
)
FILE_PACKAGES=(
    thunar thunar-volman thunar-archive-plugin tumbler ffmpegthumbnailer file-roller exo
)
APP_PACKAGES=(firefox mpv imv pavucontrol btop gnome-disk-utility ntfs-3g dosfstools steam spotify-launcher libreoffice-fresh qbittorrent)
DEV_PACKAGES=(git base-devel sudo wget curl nano jq python-pipx python-filelock rust alsa-lib pkgconf ueberzugpp)
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
# PYWAL16 (PIPX — NO AUR)
################################################################################

print_phase "pywal16 (pipx)"

# Sanity-check pipx first so a broken pipx gives a clear error.
run_command "as_user pipx --version" "Checking pipx works"
run_command "as_user pipx install --force pywal16" "Installing pywal16 via pipx"

################################################################################
# LOCALSEND (TARBALL — NO AUR) — non-fatal if GitHub is unreachable
################################################################################

print_phase "LocalSend (GitHub Release)"

install_localsend() {
    local ver icon
    ver=$(curl -fsSL --retry 3 "https://api.github.com/repos/localsend/localsend/releases/latest" \
        | grep -Po '"tag_name": "v\K[^"]*') || return 1
    [[ -n "$ver" ]] || return 1

    curl -fsSL --retry 3 \
        "https://github.com/localsend/localsend/releases/download/v${ver}/LocalSend-${ver}-linux-x86-64.tar.gz" \
        -o /tmp/localsend.tar.gz || return 1
    tar -tzf /tmp/localsend.tar.gz > /dev/null || return 1

    rm -rf /opt/localsend
    mkdir -p /opt/localsend
    tar -xzf /tmp/localsend.tar.gz -C /opt/localsend || return 1
    ln -sf /opt/localsend/localsend_app /usr/bin/localsend

    icon=$(find /opt/localsend -type f \( -name "*logo*" -o -name "*icon*" \) \
        | grep -E '\.(png|svg)$' | head -n 1) || true
    mkdir -p /opt/localsend/icons
    [[ -n "${icon:-}" ]] && cp "$icon" /opt/localsend/icons/icon.png

    cat > /usr/share/applications/localsend.desktop <<EOF
[Desktop Entry]
Name=LocalSend
Exec=/opt/localsend/localsend_app
Icon=/opt/localsend/icons/icon.png
Type=Application
Categories=Utility;Network;
EOF

    update-desktop-database /usr/share/applications/ 2>/dev/null || true
    rm -f /tmp/localsend.tar.gz
    return 0
}

if install_localsend > "$LOG_DIR/localsend.log" 2>&1; then
    print_ok "LocalSend installed from tarball (no AUR)"
else
    print_warn "LocalSend install failed (skipping)  →  $LOG_DIR/localsend.log"
fi

################################################################################
# DIRECTORY STRUCTURE
################################################################################

print_phase "Directory Structure"

CONFIG_DIRS=(
    "$CONFIG_DIR/hypr"        "$CONFIG_DIR/waybar"
    "$CONFIG_DIR/kitty"       "$CONFIG_DIR/fastfetch"
    "$CONFIG_DIR/mako"        "$CONFIG_DIR/scripts"
    "$CONFIG_DIR/wal/templates"  "$CONFIG_DIR/btop"
    "$CONFIG_DIR/gtk-3.0"     "$CONFIG_DIR/gtk-4.0"
    "$CONFIG_DIR/zed/themes"  "$CONFIG_DIR/fish"
    "$CONFIG_DIR/cava"        "$CONFIG_DIR/Thunar"
)

for dir in "${CONFIG_DIRS[@]}"; do
    as_user mkdir -p "$dir"
    print_item "${DIM}$dir${RST}"
done

as_user mkdir -p "$WAL_CACHE"
as_user mkdir -p "$USER_HOME/Pictures/Wallpapers"
as_user mkdir -p "$USER_HOME/.local/share/icons"
as_user mkdir -p "$USER_HOME/.local/share/applications"
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
for s in "${OLD_SYMLINKS[@]}"; do as_user rm -f "$s" 2>/dev/null || true; done
print_ok "Stale symlinks & conflicting files cleared"

[[ -d "$CONFIGS_SRC/hypr"                    ]] && run_command "as_user cp -rf '$CONFIGS_SRC/hypr/.' '$CONFIG_DIR/hypr/'"                                  "Hyprland config"
[[ -d "$CONFIGS_SRC/waybar"                  ]] && run_command "as_user cp -rf '$CONFIGS_SRC/waybar/.' '$CONFIG_DIR/waybar/'"                              "Waybar config"
[[ -f "$CONFIGS_SRC/kitty/kitty.conf"        ]] && run_command "as_user cp '$CONFIGS_SRC/kitty/kitty.conf' '$CONFIG_DIR/kitty/kitty.conf'"                 "Kitty config"
[[ -f "$CONFIGS_SRC/fastfetch/config.jsonc"  ]] && run_command "as_user cp '$CONFIGS_SRC/fastfetch/config.jsonc' '$CONFIG_DIR/fastfetch/config.jsonc'"     "Fastfetch config"
[[ -f "$CONFIGS_SRC/starship/starship.toml"  ]] && run_command "as_user cp '$CONFIGS_SRC/starship/starship.toml' '$CONFIG_DIR/starship.toml'"               "Starship config"
[[ -f "$CONFIGS_SRC/btop/btop.conf"          ]] && run_command "as_user cp '$CONFIGS_SRC/btop/btop.conf' '$CONFIG_DIR/btop/btop.conf'"                     "btop config"
[[ -d "$CONFIGS_SRC/cava"                    ]] && run_command "as_user cp -rf '$CONFIGS_SRC/cava/.' '$CONFIG_DIR/cava/'"                                  "cava config"
[[ -d "$CONFIGS_SRC/wal/templates"           ]] && run_command "as_user cp -rf '$CONFIGS_SRC/wal/templates/.' '$CONFIG_DIR/wal/templates/'"                "pywal templates"

# Files below are written as root, then chowned in the final step.
cat > "$CONFIG_DIR/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF
print_ok "GTK3 dark theme configured"

cat > "$CONFIG_DIR/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-icon-theme-name=Colloid-Dynamic-Dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF
print_ok "GTK4 dark theme configured"

################################################################################
# GPU-SPECIFIC ENVIRONMENT
################################################################################

print_phase "GPU environment"

GPU_ENV_FILE="$CONFIG_DIR/hypr/gpu-env.lua"
echo '-- GPU environment — auto-generated' > "$GPU_ENV_FILE"

if echo "$GPU_INFO" | grep -qi nvidia; then
    cat >> "$GPU_ENV_FILE" << 'EOF'
return {
  LIBVA_DRIVER_NAME         = "nvidia",
  XDG_SESSION_TYPE          = "wayland",
  __GLX_VENDOR_LIBRARY_NAME = "nvidia",
  GBM_BACKEND               = "nvidia-drm",
  WLR_NO_HARDWARE_CURSORS   = "1",
  __GL_GSYNC_ALLOWED        = "1",
  __GL_VRR_ALLOWED          = "1",
  QT_QPA_PLATFORM           = "wayland",
}
EOF
elif echo "$GPU_INFO" | grep -qi amd; then
    cat >> "$GPU_ENV_FILE" << 'EOF'
return {
  LIBVA_DRIVER_NAME = "radeonsi",
  XDG_SESSION_TYPE  = "wayland",
  QT_QPA_PLATFORM   = "wayland",
}
EOF
elif echo "$GPU_INFO" | grep -qi intel; then
    cat >> "$GPU_ENV_FILE" << 'EOF'
return {
  LIBVA_DRIVER_NAME = "iHD",
  XDG_SESSION_TYPE  = "wayland",
  QT_QPA_PLATFORM   = "wayland",
}
EOF
else
    cat >> "$GPU_ENV_FILE" << 'EOF'
return {
  XDG_SESSION_TYPE = "wayland",
  QT_QPA_PLATFORM  = "wayland",
}
EOF
fi
print_ok "GPU env written  →  hypr/gpu-env.lua"

################################################################################
# SCRIPTS, WALLPAPERS & SHELL
################################################################################

print_phase "Scripts, wallpapers & shell"

if [[ -d "$SCRIPTS_SRC" ]]; then
    run_command "as_user cp -rf '$SCRIPTS_SRC/.' '$CONFIG_DIR/scripts/' && as_user find '$CONFIG_DIR/scripts' -type f -exec chmod +x {} +" \
        "User scripts"
fi

WALLPAPER_TMP="/tmp/wallpapers-src"
rm -rf "$WALLPAPER_TMP"
run_command "as_user git clone --depth 1 '$WALLPAPERS_REPO' '$WALLPAPER_TMP'" "Cloning Wallpapers repository"
run_command "as_user cp -rf '$WALLPAPER_TMP/.' '$USER_HOME/Pictures/Wallpapers/' && rm -rf '$USER_HOME/Pictures/Wallpapers/.git'" "Deploying Wallpapers"
rm -rf "$WALLPAPER_TMP"

# Configure Bash (existing file is backed up once)
backup_file "$USER_HOME/.bashrc"
cat > "$USER_HOME/.bashrc" << 'EOF'
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

# Configure Fish Shell (existing file is backed up once)
backup_file "$CONFIG_DIR/fish/config.fish"
cat > "$CONFIG_DIR/fish/config.fish" << 'EOF'
set -g fish_greeting ""

if status is-interactive
    if test -f ~/.cache/wal/sequences
        cat ~/.cache/wal/sequences
    end
    type -q fastfetch; and fastfetch
end

type -q starship; and starship init fish | source

fish_add_path $HOME/.local/bin $HOME/.cargo/bin

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

if chsh -s /usr/bin/fish "$USER_NAME"; then
    print_ok "Fish shell configured (greeting disabled) and set as default shell"
else
    print_warn "Could not change default shell to fish (run: chsh -s /usr/bin/fish)"
fi

################################################################################
# COLLOID ICON THEME
################################################################################

print_phase "Colloid icon theme"

COLLOID_SRC="$CONFIG_DIR/colloid-src"
if [[ ! -d "$COLLOID_SRC" ]]; then
    run_command "as_user git clone --depth 1 https://github.com/Saltyfunnel/colloid.git '$COLLOID_SRC'" \
        "Cloning Colloid icon theme"
fi

run_command "cd '$COLLOID_SRC' && as_user ./install.sh -d '$USER_HOME/.local/share/icons' -n Colloid-Dynamic -s default" \
    "Installing Colloid-Dynamic icons"

################################################################################
# THUNAR CUSTOM ACTIONS (KITTY)
################################################################################

print_phase "Thunar Custom Actions"

cat > "$CONFIG_DIR/Thunar/uca.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
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
EOF

print_ok "Thunar 'Open Kitty Here' action configured"

################################################################################
# PYWAL SYMLINKS
################################################################################

print_phase "Pywal symlinks"

link_wal() {  # link_wal <template> <cache file> <target>
    if [[ -f "$CONFIG_DIR/wal/templates/$1" ]]; then
        as_user ln -sf "$WAL_CACHE/$2" "$3"
        print_ok "${3#$CONFIG_DIR/}"
    fi
}

link_wal "waybar-style.css" "waybar-style.css" "$CONFIG_DIR/waybar/style.css"
link_wal "mako-config"      "mako-config"      "$CONFIG_DIR/mako/config"
link_wal "zed.json"         "colors-zed.json"  "$CONFIG_DIR/zed/themes/zed.json"
link_wal "cava-config"      "cava-config"      "$CONFIG_DIR/cava/config"

################################################################################
# SERVICES & PERMISSIONS
################################################################################

print_phase "Services & permissions"

for svc in sddm bluetooth NetworkManager; do
    if systemctl enable "${svc}.service" > "$LOG_DIR/enable-${svc}.log" 2>&1; then
        print_ok "${svc} enabled"
    else
        print_warn "Could not enable ${svc}  →  $LOG_DIR/enable-${svc}.log"
    fi
done

for p in "$CONFIG_DIR" "$CACHE_DIR" "$USER_HOME/Pictures" "$USER_HOME/.local" "$USER_HOME/.bashrc"; do
    [[ -e "$p" ]] && chown -R "$USER_NAME:$USER_NAME" "$p"
done
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
_row "pacman configured"                     "multilib, ILoveCandy, Color, ParallelDownloads"
_row "system updated"                        "pacman -Syu"
_row "${#ALL_PACKAGES[@]} packages"          "pacman (cava & fish included)"
_row "pywal16"                               "pipx (PyPI, no AUR)"
_row "localsend"                             "github release tarball (no AUR)"
_row "dotfiles deployed"                     "~/.config/*"
_row "gpu environment"                       "hypr/gpu-env.lua"
_row "gtk3 & gtk4 dark theme"                "Adwaita-dark"
_row "colloid-dynamic icons"                 "~/.local/share/icons"
_row "pywal symlinks"                        "wal → cache"
_row "zed theme"                             "zed/themes/zed.json"
_row "default shell"                         "fish"
_row "sddm · bluetooth · NetworkManager"     "systemctl enable"

echo ""
echo -e "    ${DIM}logs: ${LOG_DIR}${RST}"
hr
echo ""

read -r -p "    $(echo -e "${BCYN}reboot system now? [Y/n]:${RST} ")" REBOOT_CHOICE
REBOOT_CHOICE=${REBOOT_CHOICE:-Y}

if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    echo ""
    print_ok "Rebooting..."
    reboot
fi

echo ""
