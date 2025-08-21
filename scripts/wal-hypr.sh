#!/bin/bash
# Apply pywal colors to Hyprland dynamically

set -euo pipefail

# Path to Pywal colors
PYWAL_COLORS="$HOME/.cache/wal/colors.sh"

# Path to Hyprland colors file
HYPR_COLORS="$HOME/.config/hypr/colors.conf"

if [ ! -f "$PYWAL_COLORS" ]; then
    echo "❌ Pywal colors not found at $PYWAL_COLORS"
    exit 1
fi

source "$PYWAL_COLORS"

# Generate Hyprland colors.conf
cat > "$HYPR_COLORS" <<EOL
col0=$color0
col1=$color1
col2=$color2
col3=$color3
col4=$color4
col5=$color5
col6=$color6
col7=$color7
col8=$color8
col9=$color9
col10=$color10
col11=$color11
col12=$color12
col13=$color13
col14=$color14
col15=$color15

background=$background
foreground=$foreground
active_border=$color2
inactive_border=$color0
EOL

# Reload Hyprland colors
if pgrep Hyprland >/dev/null; then
    hyprctl reload
    echo "✅ Hyprland colors updated from Pywal"
else
    echo "⚠️ Hyprland not running, colors file updated for next launch"
fi
