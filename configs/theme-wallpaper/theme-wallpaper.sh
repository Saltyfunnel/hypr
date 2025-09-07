#!/bin/bash
# ~/.config/theme-wallpaper/theme-wallpaper.sh
# Root script to orchestrate wallpaper selection and theming

ROOT_DIR="$HOME/.config/theme-wallpaper"
export ROOT_DIR
export WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
export PALETTE_JSON="$ROOT_DIR/palette.json"
export WAYBAR_CSS="$HOME/.config/waybar/style.css"
export HYPR_CONFIG="$HOME/.config/hypr/hyprland.conf"

# ------------------------
# 1️⃣ Pick wallpaper
# ------------------------
SELECTED=$(WALLPAPER_DIR="$WALLPAPER_DIR" "$ROOT_DIR/wallpaper-picker.sh") || exit 0

# ------------------------
# 2️⃣ Generate Matugen palette
# ------------------------
"$ROOT_DIR/matugen-theme.sh" "$SELECTED"

# ------------------------
# 3️⃣ Update Waybar theme (always reload first)
# ------------------------
"$ROOT_DIR/waybar-update.sh"

# ------------------------
# 4️⃣ Update Hyprland colors
# ------------------------
"$ROOT_DIR/hyprland-update.sh" "$SELECTED"

# ------------------------
# 5️⃣ Set wallpaper with swww
# ------------------------
"$ROOT_DIR/set-wallpaper.sh" "$SELECTED"

# ------------------------
# 6️⃣ Update Kitty colors safely
# ------------------------
if [ -f "$ROOT_DIR/kitty-update.sh" ]; then
    "$ROOT_DIR/kitty-update.sh" &
fi

# 7️⃣ Update Fastfetch colors
"$ROOT_DIR/fastfetch-update.sh"

# Optional: run Fastfetch immediately
fastfetch

# 8️⃣ Update Starship colors
"$ROOT_DIR/starship-update.sh"

# 7️⃣ Update GTK themes
"$ROOT_DIR/gtk-update.sh"
