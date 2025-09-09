#!/bin/bash
# ~/.config/theme-manager/applytheme.sh
# Apply wallpaper, Pywal colors, Starship, Kitty, GTK themes, Fastfetch, and Waybar

source ~/.config/theme-manager/config.sh

# -------------------------------
# Step 1: Pick & set wallpaper
# -------------------------------
~/.config/theme-manager/setwallpaper.sh

# -------------------------------
# Step 2: Generate Pywal colors
# -------------------------------
~/.config/theme-manager/setcolors.sh

# -------------------------------
# Step 3: Export Pywal colors for shell scripts
# -------------------------------
export WAL_COLOR1=$(jq -r '.colors[0]' ~/.cache/wal/colors.json)
export WAL_COLOR2=$(jq -r '.colors[1]' ~/.cache/wal/colors.json)
export WAL_COLOR3=$(jq -r '.colors[2]' ~/.cache/wal/colors.json)
export WAL_COLOR4=$(jq -r '.colors[3]' ~/.cache/wal/colors.json)

# -------------------------------
# Step 4: Reload Starship prompt
# -------------------------------
eval "$(starship init bash)"

# -------------------------------
# Step 5: Apply GTK & icon themes (optional)
# -------------------------------
if command -v gsettings &>/dev/null; then
    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
    echo "GTK & icon themes applied."
fi

# -------------------------------
# Step 6: Apply Pywal colors to Kitty
# -------------------------------
kitty @ set-colors ~/.cache/wal/colors-kitty.conf 2>/dev/null \
    || echo "Kitty remote control disabled; restart terminal to apply colors."

# -------------------------------
# Step 7: Update Fastfetch colors
# -------------------------------
FASTFETCH_CONFIG="$HOME/.config/fastfetch/config.jsonc"
if [ -f "$FASTFETCH_CONFIG" ]; then
    jq --arg c0 "$WAL_COLOR1" \
       --arg c1 "$WAL_COLOR2" \
       --arg c2 "$WAL_COLOR3" \
       --arg c3 "$WAL_COLOR4" \
       '.colors.ascii=$c1 | .colors.os=$c0 | .colors.host=$c2 | .colors.cpu=$c3' \
       "$FASTFETCH_CONFIG" > "$FASTFETCH_CONFIG.tmp" && mv "$FASTFETCH_CONFIG.tmp" "$FASTFETCH_CONFIG"

    fastfetch -c "$FASTFETCH_CONFIG"
fi

# -------------------------------
# Step 8: Generate Waybar-compatible CSS
# -------------------------------
wal -R -o 'cp ~/.cache/wal/colors-waybar.css ~/.config/waybar/colors.css'

# -------------------------------
# Step 9: Start Waybar (if not already running)
# -------------------------------
# Kill any existing instance first
pkill waybar 2>/dev/null
# Start Waybar in the background
waybar &

echo "Full theme applied, Waybar started!"
