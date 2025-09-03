#!/usr/bin/env bash

# Launch Waypaper interactively
waypaper &  # runs in background so script can continue

# Wait for user to select a wallpaper
# You might need to tweak the sleep depending on your Waypaper setup
sleep 1

# Waypaper writes the chosen wallpaper path to its state file
# Adjust path if your Waypaper version uses a different file
WP_FILE="$HOME/.cache/waypaper/current_wallpaper"

# Wait until the file exists
while [ ! -f "$WP_FILE" ]; do
    sleep 0.1
done

# Apply Pywal to the selected wallpaper
wal -i "$(cat "$WP_FILE")" -q
