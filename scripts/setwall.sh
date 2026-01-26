#!/bin/bash
# ~/.config/scripts/setwall.sh

# 1. Simple Pathing
WALL="$1"

# 2. The Original Pywal Command (The one that worked)
# We use the standard wal -i which you had before.
wal -i "$WALL"

# 3. Simple SWWW (No fancy AMD flags if they were causing the miss)
# If it worked before, this is the syntax it used:
swww img "$WALL" --transition-type simple

# 4. Refresh everything 
# We wait 0.5s to make sure the cache files are actually WRITTEN
sleep 0.5

# Reload Waybar
killall waybar
waybar &

# Reload Mako
killall mako
mako &

# Reload Hyprland Borders
hyprctl reload
