#!/bin/bash
WALL="$1"

if [ -z "$WALL" ]; then
    echo "Usage: setwall <path-to-image>"
    exit 1
fi

if [ ! -f "$WALL" ]; then
    echo "Error: Wallpaper file not found at $WALL"
    exit 1
fi

# 1. Preload and set the wallpaper using hyprpaper instantly
hyprpaper unload all
hyprpaper preload "$WALL"
hyprpaper wallpaper ", $WALL"

# 2. Run wal safely
wal -i "$WALL" --backend haiku

# 3. Symlink current wallpaper
ln -sf "$WALL" ~/.cache/current-wallpaper

# 4. Folder icon recolor
[[ -f "$HOME/.config/scripts/recolor_folders.sh" ]] && \
    bash "$HOME/.config/scripts/recolor_folders.sh" &

# 5. Restart waybar + mako + reload hyprland
killall waybar 2>/dev/null; waybar &
killall mako 2>/dev/null; sleep 0.1; mako & disown
hyprctl reload

notify-send -i "$WALL" "Theme Updated" "$(basename "$WALL")"

# 6. Sync colors to global cache for SDDM access
if [ -f "$HOME/.cache/wal/colors.json" ]; then
    cp -f "$HOME/.cache/wal/colors.json" /var/cache/wal/colors.json 2>/dev/null || true
    chmod 644 /var/cache/wal/colors.json 2>/dev/null || true
fi
