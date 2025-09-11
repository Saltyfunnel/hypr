#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) | shuf -n 1)
swww img "$WALLPAPER"
matugen image "$WALLPAPER"
