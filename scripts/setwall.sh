#!/bin/bash
WALL="$1"

# 1. Let wal run fully and apply everything as normal
wal -i "$WALL"

# 2. TRIGGER THE ICON RECOLOR (The missing link!)
# We run this BEFORE the notifications so it's done by the time you look
if [ -f "$HOME/.config/scripts/recolor_folders.sh" ]; then
    echo "🎨 Patching folder icons..."
    # Running without '&' ensures it finishes before we reload everything else
    bash "$HOME/.config/scripts/recolor_folders.sh"
else
    echo "⚠️ Recolor script not found at ~/.config/scripts/recolor_folders.sh"
fi

# 3. Set wallpaper immediately after
swww img "$WALL" --transition-type simple

# 4. Update fastfetch wallpaper cache
ln -sf "$WALL" ~/.cache/current-wallpaper

# 5. Restart waybar and mako in parallel
{ killall waybar 2>/dev/null; waybar & } &
{ killall mako 2>/dev/null; sleep 0.1; mako & disown; } &

# 6. Final UI Sync
hyprctl reload

notify-send -i "$WALL" "Theme Updated" "Colors & Icons synced to $(basename "$WALL")"
