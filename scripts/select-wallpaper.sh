#!/bin/bash
set -euo pipefail

# ===============================
# Variables
# ===============================
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

CONFIG_DIR="$USER_HOME/.config"
WALLPAPERS_DIR="$CONFIG_DIR/assets/wallpapers"
KITTY_CONF="$CONFIG_DIR/kitty/kitty.conf"
STARSHIP_CONFIG="$CONFIG_DIR/starship.toml"
WAL_CACHE="$USER_HOME/.cache/wal/colors.css"

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
print_info "Selecting wallpaper..."
WALL_NAME=$(ls "$WALLPAPERS_DIR" | wofi --prompt "Select Wallpaper:" --dmenu)

if [[ -z "$WALL_NAME" ]]; then
    print_error "No wallpaper selected. Exiting."
    exit 1
fi

WALL_PATH="$WALLPAPERS_DIR/$WALL_NAME"
print_success "Selected wallpaper: $WALL_PATH"

# ===============================
# Step 2: Set wallpaper
# ===============================
print_info "Applying wallpaper via swww..."
swww img "$WALL_PATH" --transition-fps 255 --transition-type outer --transition-duration 0.8
print_success "Wallpaper applied."

# ===============================
# Step 3: Generate Pywal colors
# ===============================
print_info "Generating Pywal colors..."
wal -i "$WALL_PATH" --backend wal
print_success "Pywal colors applied."

# ===============================
# Step 4: Update Kitty terminal
# ===============================
print_info "Updating Kitty terminal colors..."
if [[ -f "$KITTY_CONF" ]]; then
    COLOR_BG=$(awk -F: '/background/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CACHE" | head -1)
    COLOR_FG=$(awk -F: '/foreground/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CACHE" | head -1)
    COLOR_ACCENT=$(awk -F: '/color1/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CACHE" | head -1)

    sed -i -e "s/^background .*/background $COLOR_BG/" \
           -e "s/^foreground .*/foreground $COLOR_FG/" \
           -e "s/^color1 .*/color1 $COLOR_ACCENT/" \
           "$KITTY_CONF"
    print_success "Kitty configuration updated. Restart Kitty to see changes."
else
    print_warning "Kitty config not found at $KITTY_CONF"
fi

# ===============================
# Step 5: Update Starship prompt
# ===============================
print_info "Updating Starship prompt..."
COLOR_BG=$(awk -F: '/background/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CACHE" | head -1)
COLOR_FG=$(awk -F: '/foreground/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CACHE" | head -1)
COLOR_ACCENT=$(awk -F: '/color1/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CACHE" | head -1)

cat > "$STARSHIP_CONFIG" <<EOF
format = "\$os\$username\$directory\$git_branch\$git_status\$c\$elixir\$elm\$golang\$gradle\$haskell\$java\$julia\$nodejs\$nim\$rust\$scala\$docker_context\$time"

add_newline = false

[username]
show_always = true
style_user = "fg:$COLOR_ACCENT,bg:$COLOR_BG"
style_root = "fg:$COLOR_ACCENT,bg:$COLOR_BG"
format = '[$user]($style)'

[os]
disabled = true

[directory]
style = "fg:$COLOR_FG,bg:$COLOR_ACCENT"
format = "[ \$path ](\$style)"
truncation_length = 3
truncation_symbol = "…/"

[c]
symbol = " "
style = "fg:$COLOR_FG,bg:$COLOR_ACCENT"
format = '[ \$symbol (\$version) ](\$style)'

[git_branch]
symbol = ""
style = "fg:$COLOR_FG,bg:$COLOR_ACCENT"
format = '[ \$symbol \$branch ](\$style)'

[git_status]
style = "fg:$COLOR_FG,bg:$COLOR_ACCENT"
format = '[$all_status$ahead_behind]($style)'

[docker_context]
symbol = " "
style = "fg:$COLOR_FG,bg:$COLOR_ACCENT"
format = '[ \$symbol \$context ](\$style)'

[time]
disabled = false
time_format = "%R"
style = "fg:$COLOR_FG,bg:$COLOR_ACCENT"
format = '[ ⏰ \$time ](\$style)'
EOF

chown "$USER_NAME:$USER_NAME" "$STARSHIP_CONFIG"
print_success "Starship configured with Pywal colors."

# ===============================
# Step 6: Launch or refresh Yazi
# ===============================
print_info "Launching or refreshing Yazi..."
if command -v yazi &>/dev/null; then
    if ! pgrep -x yazi >/dev/null; then
        run_as_user "env DISPLAY=$DISPLAY XDG_SESSION_TYPE=$XDG_SESSION_TYPE setsid yazi >/dev/null 2>&1 &"
        print_success "Yazi launched."
    else
        print_info "Yazi is already running and should auto-refresh colors from Pywal."
    fi
else
    print_warning "Yazi not installed. Install via AUR to enable dynamic theming."
fi

print_success "Wallpaper selection and theming complete!"
