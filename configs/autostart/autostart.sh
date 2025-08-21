#!/bin/bash

# Wait for Hyprpaper to set wallpaper
sleep 2

# Run pywal script from repo
"$HOME/.config/scripts/wal-hypr.sh" &

# Optional: start apps
# "$HOME/.config/waybar/waybar" &
# "$HOME/.config/dunst/dunst" &
