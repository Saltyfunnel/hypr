#!/bin/bash
# ~/.config/theme-wallpaper/matugen-theme.sh
# Generates palette.json using Matugen for the selected wallpaper

SELECTED_WALLPAPER="$1"
if [ -z "$SELECTED_WALLPAPER" ]; then
    echo "Error: No wallpaper path provided." >&2
    exit 1
fi

# Ensure PALETTE_JSON is set (exported from root script)
: "${PALETTE_JSON:?Need to set PALETTE_JSON}"

# Determine brightness to choose dark/light mode automatically
BRIGHTNESS=$(convert "$SELECTED_WALLPAPER" -resize 1x1 txt:- | \
    grep -oE "[0-9]{1,3},[0-9]{1,3},[0-9]{1,3}" | \
    awk -F, '{print ($1+$2+$3)/3}')

PALETTE_MODE="dark"
[ $(echo "$BRIGHTNESS > 128" | bc) -eq 1 ] && PALETTE_MODE="light"

# Generate the palette with matugen and write JSON
matugen image "$SELECTED_WALLPAPER" -m "$PALETTE_MODE" --json hex > "$PALETTE_JSON"
