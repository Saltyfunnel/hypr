#!/bin/bash
# ~/.config/theme-wallpaper/wallpaper-picker.sh

: "${WALLPAPER_DIR:=$HOME/Pictures/Wallpapers}"

if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "Wallpaper directory does not exist: $WALLPAPER_DIR" >&2
    exit 1
fi

mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \))
if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    echo "No wallpapers found in $WALLPAPER_DIR" >&2
    exit 1
fi

SELECTED=$(printf '%s\n' "${WALLPAPERS[@]}" | rofi -dmenu -i -lines 10 -p "Select Wallpaper")
[ -z "$SELECTED" ] && exit 0

pkill -f "kitty --name wallpaper-preview" >/dev/null 2>&1
kitty --name wallpaper-preview --class wallpaper-preview --hold --title "Wallpaper Preview" \
      sh -c "chafa '$SELECTED' --fill=block --symbols=block --colors=8" &

CONFIRM=$(echo -e "Yes\nNo" | rofi -dmenu -i -lines 2 -p "Set this wallpaper?")
pkill -f "kitty --name wallpaper-preview" >/dev/null 2>&1
[ "$CONFIRM" != "Yes" ] && exit 0

echo "$SELECTED"