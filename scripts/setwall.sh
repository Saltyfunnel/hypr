#!/bin/bash
WALL="$1"

# Visual feedback immediately
swww img "$WALL" --transition-type simple &

# Generate palette (this is the slow part, let it run while swww animates)
wal -i "$WALL" --backend haiku  # or fast/colorz if installed — much faster than default

# Folder icons (now has fresh colours)
[ -f "$HOME/.config/scripts/recolor_folders.sh" ] && \
    bash "$HOME/.config/scripts/recolor_folders.sh" &

# Symlink wallpaper cache
ln -sf "$WALL" ~/.cache/current-wallpaper

# Restart waybar + mako in parallel
killall waybar 2>/dev/null; waybar &
killall mako 2>/dev/null; sleep 0.1; mako & disown

# Reload hyprland config
hyprctl reload

notify-send -i "$WALL" "Theme Updated" "$(basename "$WALL")"
