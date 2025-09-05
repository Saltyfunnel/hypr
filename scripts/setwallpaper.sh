#!/bin/bash
# setwallpaper.sh
# Wallpaper + full Waybar theming for Hyprland with smaller modules and safe colors

set -euo pipefail

# Paths
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
HYPR_COLORS="$HOME/.cache/wal/colors-hyprland.conf"
WAYBAR_CSS="$HOME/.config/waybar/style.css"

mkdir -p "$WALLPAPER_DIR" "$(dirname "$HYPR_COLORS")" "$(dirname "$WAYBAR_CSS")"

# Step 1: Select wallpaper via Rofi
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) \
    | rofi -dmenu -i -p "Select Wallpaper")
[[ -n "$WALLPAPER" ]] || { echo "No wallpaper selected"; exit 1; }

# Step 2: Apply wallpaper via swww
pgrep -x swww-daemon >/dev/null || swww init
swww img "$WALLPAPER"
sleep 0.2

# Step 3: Generate Pywal colors
wal -i "$WALLPAPER" -n

# Step 4: Generate safe Waybar + Hyprland colors
python3 - <<'EOF'
import os, json

HOME = os.path.expanduser("~")
colors_json = os.path.join(HOME, ".cache/wal/colors.json")
hypr_file = os.path.join(HOME, ".cache/wal/colors-hyprland.conf")
waybar_file = os.path.join(HOME, ".config/waybar/style.css")

def safe_color(c, fallback="#FFFFFF"):
    if c and c.startswith("#") and len(c) == 7:
        return c
    return fallback

def hex_to_rgb(h):
    h = h.lstrip('#')
    try:
        return tuple(int(h[i:i+2],16) for i in (0,2,4))
    except:
        return (0,0,0)

def darken(rgb, factor=0.6):
    return tuple(int(c*factor) for c in rgb)

def rgb_str(rgb):
    return f"{rgb[0]},{rgb[1]},{rgb[2]}"

# Load Pywal
try:
    with open(colors_json) as f:
        data = json.load(f)
except:
    data = {'colors':{}, 'special':{}}

bg = safe_color(data.get('special', {}).get('background', '#000000'))
fg = safe_color(data.get('special', {}).get('foreground', '#FFFFFF'))

colors = [safe_color(data.get('colors', {}).get(f'color{i}', '#888888')) for i in range(8)]
dark_colors = [darken(hex_to_rgb(c)) for c in colors]

# Hyprland colors
hypr_lines = [
    f"$background = rgba({bg[1:]}ff)",
    f"$foreground = rgba({fg[1:]}ff)",
    f"$active_border = rgba({colors[1][1:]}ff)",
    f"$inactive_border = rgba({colors[0][1:]}aa)",
    f"$group_border_active = rgba({colors[2][1:]}ff)",
    f"$group_border_inactive = rgba({colors[3][1:]}aa)"
]
with open(hypr_file, "w") as f:
    f.write("\n".join(hypr_lines))

# Waybar CSS
modules = ["hyprland/workspaces", "network", "battery", "pulseaudio", "cpu", "memory", "clock"]
css_modules = []
for i, module in enumerate(modules):
    rgb = rgb_str(dark_colors[i % len(dark_colors)])
    css_modules.append(f"""#{module.replace('/', '\\/')} {{
    background: rgba({rgb},0.85);
    border-radius: 10px;
    padding: 0px 10px;
    color: {fg};
}}""")
css_modules_str = "\n\n".join(css_modules)

css = f"""
* {{
    font-family: JetBrainsMono Nerd Font, sans-serif;
    font-size: 14px; /* smaller font */
    background: rgba(0,0,0,0);
    color: {fg};
}}

window#waybar {{
    background: rgba(0,0,0,0);
    border: none;
    box-shadow: none;
}}

.module {{
    box-shadow: none;
    border: none;
    border-radius: 4px;
    padding: 1px 4px;
}}

{css_modules_str}

/* Hover effect */
.module:hover {{
    background: rgba(255,255,255,0.1);
}}
"""

with open(waybar_file, "w") as f:
    f.write(css)
EOF

# Step 5: Reload Hyprland
hyprctl reload || echo "⚠️ hyprctl reload failed"

# Step 6: Restart Waybar safely
pkill waybar
nohup waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css >/dev/null 2>&1 &

sleep 0.2
exit 0
