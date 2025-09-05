#!/bin/bash
# setwallpaper.sh
# Apply wallpaper, generate Hyprland + Waybar colors with Pywal

set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
HYPR_COLORS="$HOME/.cache/wal/colors-hyprland.conf"
WAYBAR_THEME="$HOME/.config/waybar/style.css"

# Ensure directories exist
mkdir -p "$WALLPAPER_DIR" "$(dirname "$HYPR_COLORS")" "$(dirname "$WAYBAR_THEME")"

# Step 1: Choose wallpaper via Rofi
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) \
            | rofi -dmenu -i -p "Select Wallpaper")

[[ -n "$WALLPAPER" ]] || { echo "No wallpaper selected. Exiting."; exit 1; }

# Step 2: Start swww-daemon if not running, apply wallpaper
pgrep -x swww-daemon >/dev/null || swww init
swww img "$WALLPAPER"

# Step 3: Generate Pywal colors
wal -i "$WALLPAPER" -n

# Step 4: Convert Pywal JSON to Hyprland + Waybar formats
python3 - <<'EOF'
import json, os

HOME = os.path.expanduser("~")
colors_json = os.path.join(HOME, ".cache/wal/colors.json")
hypr_file = os.path.join(HOME, ".cache/wal/colors-hyprland.conf")
waybar_file = os.path.join(HOME, ".config/waybar/style.css")

with open(colors_json) as f:
    data = json.load(f)

def clean(c): return c.replace("#","").upper()

bg = clean(data['special'].get('background','000000'))
fg = clean(data['special'].get('foreground','FFFFFF'))
c0 = clean(data['colors'].get('color0','888888'))
c1 = clean(data['colors'].get('color1','FF0000'))
c2 = clean(data['colors'].get('color2','00FF00'))
c3 = clean(data['colors'].get('color3','888888'))

# Hyprland colors using $variable syntax
hypr_lines = [
    f"$background = rgba({bg}ff)",
    f"$foreground = rgba({fg}ff)",
    f"$active_border = rgba({c1}ff)",
    f"$inactive_border = rgba({c0}aa)",
    f"$group_border_active = rgba({c2}ff)",
    f"$group_border_inactive = rgba({c3}aa)"
]

with open(hypr_file, "w") as f:
    f.write("\n".join(hypr_lines))

# Waybar CSS
waybar_lines = f"""
* {{
    background: #{bg};
    color: #{fg};
}}
#workspaces {{
    background: #{bg};
}}
.module {{
    color: #{fg};
}}
.module:hover {{
    color: #{c2};
}}
"""
with open(waybar_file, "w") as f:
    f.write(waybar_lines)
EOF


# Step 5: Reload Hyprland + Waybar
hyprctl reload || echo "⚠️ hyprctl reload failed"
# Instead of pkill, we'll send a proper signal to Waybar
if pgrep -x waybar > /dev/null; then
    waybar-msg cmd restart
else
    echo "⚠️ Waybar is not running."
fi

echo "✅ Wallpaper applied and colors updated for Hyprland + Waybar."
