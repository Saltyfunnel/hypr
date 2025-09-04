#!/bin/bash
set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
HYPR_COLORS="$HOME/.cache/wal/colors-hyprland.conf"
WAYBAR_THEME="$HOME/.config/waybar/style.css"

mkdir -p "$WALLPAPER_DIR" "$(dirname "$HYPR_COLORS")" "$(dirname "$WAYBAR_THEME")"

# Step 1: Choose wallpaper via Rofi
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) \
            | rofi -dmenu -i -p "Select Wallpaper")
[[ -z "$WALLPAPER" ]] && exit 1

# Step 2: Start swww daemon if needed and set wallpaper
pgrep -x swww-daemon >/dev/null || swww init
swww img "$WALLPAPER"

# Step 3: Pywal colors
wal -i "$WALLPAPER" -n

# Step 4: Update Hyprland + Waybar
python3 - <<'EOF'
import json, os

HOME = os.path.expanduser("~")
colors_json = os.path.join(HOME, ".cache/wal/colors.json")
hypr_file = os.path.join(HOME, ".cache/wal/colors-hyprland.conf")
waybar_file = os.path.join(HOME, ".config/waybar/style.css")

with open(colors_json) as f:
    data = json.load(f)

def clean(c): return c.replace("#","").upper()

bg = clean(data['special'].get('background', '000000'))
fg = clean(data['special'].get('foreground', 'FFFFFF'))
c0 = clean(data['colors'].get('color0', '888888'))
c1 = clean(data['colors'].get('color1', 'FF0000'))
c2 = clean(data['colors'].get('color2', '00FF00'))
c3 = clean(data['colors'].get('color3', '888888'))

# Hyprland
hypr_lines = [
    f"col.background = #{c0}ff",
    f"col.foreground = #{c3}ff",
    f"col.active_border = #{c1}ff",
    f"col.inactive_border = #{c0}aa",
    f"col.group_border_active = #{c2}ff",
    f"col.group_border_inactive = #{c3}aa"
]
with open(hypr_file, "w") as f:
    f.write("\n".join(hypr_lines))

# Waybar
waybar_lines = f"""
* {{
    background: #{bg};
    color: #{fg};
}}
#workspaces {{ background: #{bg}; }}
.module {{ color: #{fg}; }}
.module:hover {{ color: #{c2}; }}
"""
with open(waybar_file, "w") as f:
    f.write(waybar_lines)
EOF

# Reload
hyprctl reload || echo "⚠️ Hyprland reload failed"
pkill -USR1 waybar || echo "⚠️ Waybar reload failed"

echo "✅ Wallpaper applied and colors updated"
