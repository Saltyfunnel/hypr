#!/bin/bash
# ~/.config/theme-wallpaper/waybar-update.sh
# Generate Waybar CSS from palette.json

# Ensure required environment variables are set
: "${WAYBAR_CSS:?Need to set WAYBAR_CSS}"
: "${PALETTE_JSON:?Need to set PALETTE_JSON}"

#!/bin/bash
# ~/.config/theme-wallpaper/waybar-update.sh
# Generates waybar/style.css from palette.json safely

WAYBAR_CSS="$HOME/.config/waybar/style.css"
PALETTE_JSON="$HOME/.config/theme-wallpaper/palette.json"

# Extract colors safely with fallbacks
INACTIVE=$(jq -r '.colors.dark.secondary // "#b5cad7"' "$PALETTE_JSON")
ACTIVE=$(jq -r '.colors.dark.primary // "#8dcff2"' "$PALETTE_JSON")
FOREGROUND=$(jq -r '.colors.dark.on_background // "#dfe3e7"' "$PALETTE_JSON")

# Generate CSS
cat > "$WAYBAR_CSS" <<EOF
* {
    background: transparent;
}

/* Default module */
.module {
    background: rgba(0,0,0,0.7);
    border-radius: 10px;
    padding: 2px 10px;
    margin: 4px 6px;   /* top/bottom, left/right */
    color: $INACTIVE;
}

/* Active module text */
.module.active {
    color: $ACTIVE;
}

/* Workspace/window modules */
.module#hyprland-window,
.module#hyprland-workspaces {
    background: rgba(0,0,0,0.5);
    border-radius: 6px;
    padding: 2px 8px;
    margin: 4px 6px;
    color: $FOREGROUND;
}

/* Custom modules */
.module#custom-spotify,
.module#custom-power {
    background: rgba(0,0,0,0.7);
    border-radius: 6px;
    padding: 2px 8px;
    margin: 4px 6px;
    color: $INACTIVE;
}

.module#custom-spotify.active,
.module#custom-power.active {
    color: $ACTIVE;
}
EOF

# Reload Waybar safely
if pgrep waybar >/dev/null; then
    pkill -USR2 waybar
else
    waybar &
fi
