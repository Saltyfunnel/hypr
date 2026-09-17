#!/bin/bash
WALL="$1"

# 1. Fire the wallpaper transition immediately
awww img "$WALL" \
    --transition-type center \
    --transition-duration 0.6 \
    --transition-fps 60 &

# 2. Run pywal synchronously so it actually generates the files and blocks until done
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
