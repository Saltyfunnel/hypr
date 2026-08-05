#!/bin/bash
WALL="$1"

# Wallpaper transition immediately (visual feedback)
awww img "$WALL" --transition-type simple &

# Generate palette — blocks until done, templates written
wal -i "$WALL" --backend haiku

# Symlink current wallpaper
ln -sf "$WALL" ~/.cache/current-wallpaper

# Folder icon recolor (background)
[[ -f "$HOME/.config/scripts/recolor_folders.sh" ]] && \
    bash "$HOME/.config/scripts/recolor_folders.sh" &

# Restart waybar + mako
killall waybar 2>/dev/null; waybar &
killall mako 2>/dev/null; sleep 0.1; mako & disown

# Reload hyprland (templates are guaranteed written by now)
hyprctl reload

notify-send -i "$WALL" "Theme Updated" "$(basename "$WALL")"
