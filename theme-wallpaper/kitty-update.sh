#!/bin/bash
PALETTE_JSON="$HOME/.config/theme-wallpaper/palette.json"
KITTY_CONF="$HOME/.config/kitty/colors.conf"

# Exit gracefully if palette not found
[ ! -f "$PALETTE_JSON" ] && echo "palette.json missing" && exit 0

PRIMARY=$(jq -r '.colors.dark.primary // "#feb0d1"' "$PALETTE_JSON")
SECONDARY=$(jq -r '.colors.dark.secondary // "#e1bdca"' "$PALETTE_JSON")
FOREGROUND=$(jq -r '.colors.dark.on_background // "#eedfe3"' "$PALETTE_JSON")
BACKGROUND=$(jq -r '.colors.dark.background // "#191114"' "$PALETTE_JSON")

cat > "$KITTY_CONF" <<EOF
foreground   $FOREGROUND
background   $BACKGROUND
cursor       $PRIMARY
selection_foreground $BACKGROUND
selection_background $FOREGROUND
color0  $BACKGROUND
color1  $PRIMARY
color2  $SECONDARY
color3  $SECONDARY
color4  $PRIMARY
color5  $PRIMARY
color6  $SECONDARY
color7  $FOREGROUND
color8  $BACKGROUND
color9  $PRIMARY
color10 $SECONDARY
color11 $SECONDARY
color12 $PRIMARY
color13 $PRIMARY
color14 $SECONDARY
color15 $FOREGROUND
EOF

# Run reload in background, do not block
kitty +kitten themes --reload-in=all "$KITTY_CONF" >/dev/null 2>&1 &
