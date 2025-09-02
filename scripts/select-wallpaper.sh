#!/bin/bash
set -euo pipefail

# ===============================
# Variables
# ===============================
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

CONFIG_DIR="$USER_HOME/.config"
WALLPAPERS_DIR="$CONFIG_DIR/assets/wallpapers"
TOFI_CONFIGS=("$CONFIG_DIR/tofi/configA" "$CONFIG_DIR/tofi/configV")
FASTFETCH_CONFIG="$CONFIG_DIR/fastfetch/config.jsonc"

# ===============================
# Helper functions
# ===============================
print_info()    { echo -e "\033[0;34m[I]\033[0m $1"; }
print_success() { echo -e "\033[0;32m[S]\033[0m $1"; }
print_warning() { echo -e "\033[0;33m[W]\033[0m $1"; }
print_error()   { echo -e "\033[0;31m[E]\033[0m $1"; }

run_as_user() {
    sudo -u "$USER_NAME" bash -c "$1"
}

# ===============================
# Step 1: Select wallpaper
# ===============================
print_info "Selecting wallpaper via Tofi..."
WALL_NAME=$(ls "$WALLPAPERS_DIR" | tofi --prompt-text="Select Wallpaper:" --fuzzy-match=true)

if [[ -z "$WALL_NAME" ]]; then
    print_error "No wallpaper selected. Exiting."
    exit 1
fi

WALL_PATH="$WALLPAPERS_DIR/$WALL_NAME"
print_success "Selected wallpaper: $WALL_PATH"

# ===============================
# Step 2: Set wallpaper via swww
# ===============================
print_info "Setting wallpaper via swww..."
swww img "$WALL_PATH" --transition-fps 255 --transition-type outer --transition-duration 0.8
print_success "Wallpaper applied."

# ===============================
# Step 3: Generate Pywal palette
# ===============================
print_info "Generating Pywal colors..."
wal -i "$WALL_PATH" --backend wal
print_success "Pywal colors applied."

# Extract colors
COLOR_BG=$(awk -F: '/background/ {gsub(/[ ;]/,"",$2); print $2}' "$USER_HOME/.cache/wal/colors.css" | head -1)
COLOR_FG=$(awk -F: '/foreground/ {gsub(/[ ;]/,"",$2); print $2}' "$USER_HOME/.cache/wal/colors.css" | head -1)
COLOR_SEL=$(awk -F: '/color1/ {gsub(/[ ;]/,"",$2); print $2}' "$USER_HOME/.cache/wal/colors.css" | head -1)

# ===============================
# Step 4: Update Tofi configs
# ===============================
print_info "Updating Tofi configs with Pywal colors..."
for cfg in "${TOFI_CONFIGS[@]}"; do
    if [[ -f "$cfg" ]]; then
        sed -i "s/^background-color.*/background-color = $COLOR_BG/" "$cfg"
        sed -i "s/^text-color.*/text-color = $COLOR_FG/" "$cfg"
        sed -i "s/^selection-color.*/selection-color = $COLOR_SEL/" "$cfg"
    else
        print_warning "Tofi config not found: $cfg"
    fi
done
print_success "Tofi configs updated."

# ===============================
# Step 5: Refresh terminals with Fastfetch (ASCII only)
# ===============================
print_info "Configuring Fastfetch..."
for rc in ".bashrc" ".zshrc"; do
    RC_PATH="$USER_HOME/$rc"
    if [[ -f "$RC_PATH" ]]; then
        # Add Fastfetch if missing
        if ! grep -qF 'fastfetch' "$RC_PATH"; then
            echo -e "\n# Run Fastfetch on terminal start\nfastfetch --no-img" >> "$RC_PATH"
        fi
    fi
done
print_success "Terminals configured with Fastfetch ASCII."

# ===============================
# Step 6: Launch or refresh Yazi (Qt file manager)
# ===============================
print_info "Launching or refreshing Yazi..."
if command -v yazi &>/dev/null; then
    if ! pgrep -x yazi >/dev/null; then
        run_as_user "env DISPLAY=$DISPLAY XDG_SESSION_TYPE=$XDG_SESSION_TYPE setsid yazi >/dev/null 2>&1 &"
        print_success "Yazi launched."
    else
        print_info "Yazi is already running. It should pick up new Pywal colors."
    fi
else
    print_warning "Yazi not installed. Install via AUR to enable dynamic Qt file manager theming."
fi

print_success "Wallpaper selection and theming complete!"
