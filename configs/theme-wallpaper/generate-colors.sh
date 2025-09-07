# generate-colors.sh
#!/bin/bash
# Reads palette.json and writes colors.css for Waybar

PALETTE_JSON="$HOME/.config/theme-wallpaper/palette.json"
WAYBAR_COLORS="$HOME/.config/waybar/colors.css"

PRIMARY=$(jq -r '.colors.dark.primary // "#8dcff2"' "$PALETTE_JSON")
SECONDARY=$(jq -r '.colors.dark.secondary // "#b5cad7"' "$PALETTE_JSON")
BACKGROUND=$(jq -r '.colors.dark.background // "#0f1417"' "$PALETTE_JSON")
FOREGROUND=$(jq -r '.colors.dark.on_background // "#dfe3e7"' "$PALETTE_JSON")

cat > "$WAYBAR_COLORS" <<EOF
:root {
    --primary: $PRIMARY;
    --secondary: $SECONDARY;
    --background: $BACKGROUND;
    --foreground: $FOREGROUND;
}
EOF
