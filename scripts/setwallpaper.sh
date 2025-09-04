#!/bin/bash
# setwallpaper.sh
# Select a wallpaper, apply it, and safely update Hyprland colors

set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
HYPR_COLORS="$HOME/.cache/wal/colors-hyprland.hypr"

# Ensure colors file directory exists
mkdir -p "$(dirname "$HYPR_COLORS")"

# Step 0: Create default colors if missing
if [[ ! -f "$HYPR_COLORS" ]]; then
    cat > "$HYPR_COLORS" <<'EOF'
col.background = rgba(000000ff)
col.foreground = rgba(ffffffff)
col.active_border = rgba(ff0000ff)
col.inactive_border = rgba(888888aa)
col.group_border_active = rgba(00ff00ff)
col.group_border_inactive = rgba(888888aa)
EOF
fi

# Step 1: Choose wallpaper via Rofi
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) \
            | rofi -dmenu -i -p "Select Wallpaper")

if [[ -z "$WALLPAPER" ]]; then
    echo "No wallpaper selected. Exiting."
    exit 1
fi

# Step 2: Apply wallpaper
swww img "$WALLPAPER"

# Step 3: Generate Pywal colors safely
wal -i "$WALLPAPER" -n

# Step 4: Convert Pywal JSON to Hyprland-friendly format
python3 - <<EOF
import json, os

colors_json = os.path.expanduser("$HOME/.cache/wal/colors.json")
output_file = os.path.expanduser("$HYPR_COLORS")

with open(colors_json) as f:
    data = json.load(f)

def clean(c): 
    return c.replace("#","").upper()

lines = [
    f"col.background = rgba({clean(data['colors']['background'])}ff)",
    f"col.foreground = rgba({clean(data['colors']['foreground'])}ff)",
    f"col.active_border = rgba({clean(data['colors']['color1'])}ff)",
    f"col.inactive_border = rgba({clean(data['colors']['color0'])}aa)",
    f"col.group_border_active = rgba({clean(data['colors']['color2'])}ff)",
    f"col.group_border_inactive = rgba({clean(data['colors']['color3'])}aa)"
]

with open(output_file, "w") as f:
    f.write("\n".join(lines))
EOF

# Step 5: Reload Hyprland
hyprctl reload || echo "⚠️ hyprctl reload failed, check Hyprland logs"

echo "✅ Wallpaper applied and colors updated."
