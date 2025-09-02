#!/bin/bash
set -euo pipefail

# ===============================
# Variables
# ===============================
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

CONFIG_DIR="$USER_HOME/.config"
WALLPAPERS_DIR="$CONFIG_DIR/assets/wallpapers"

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
wal -i "$WALL_PATH"
print_success "Pywal colors applied."

# ===============================
# Step 4: Reload GTK apps / terminals
# ===============================
print_info "Reloading Waybar, Starship, Fastfetch..."
for rc in ".bashrc" ".zshrc"; do
    RC_PATH="$USER_HOME/$rc"
    if [[ -f "$RC_PATH" ]]; then
        # Add Fastfetch if missing
        if ! grep -qF 'fastfetch --kitty-direct' "$RC_PATH"; then
            echo -e "\n# Run fastfetch on terminal start\nfastfetch --kitty-direct $CONFIG_DIR/fastfetch/archkitty.png" >> "$RC_PATH"
        fi
        # Add Starship if missing
        if ! grep -qF 'eval "$(starship init' "$RC_PATH"; then
            shell_name="${rc#.}"  # bash/zsh
            echo -e "\n$(eval "echo 'eval \"\$(starship init $shell_name)\"'")" >> "$RC_PATH"
        fi
    fi
done
print_success "Terminals configured."

# ===============================
# Step 5: Launch or refresh Yazi
# ===============================
print_info "Launching or refreshing Yazi..."
if command -v yazi &>/dev/null; then
    if ! pgrep -x yazi >/dev/null; then
        # Launch Yazi in user session with Wayland variables
        run_as_user "env DISPLAY=$DISPLAY XDG_SESSION_TYPE=$XDG_SESSION_TYPE QT_QPA_PLATFORM=wayland setsid yazi >/dev/null 2>&1 &"
        print_success "Yazi launched."
    else
        print_info "Yazi is already running and should auto-refresh colors from Pywal."
    fi
else
    print_warning "Yazi not installed. Install via AUR to enable dynamic Qt file manager theming."
fi

print_success "Wallpaper selection and theming complete!"
