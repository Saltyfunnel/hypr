#!/bin/bash
# Updates Fastfetch config using Matugen palette

PALETTE_JSON="$HOME/.config/theme-wallpaper/palette.json"
FASTFETCH_CONF="$HOME/.config/fastfetch/config.conf"

# Extract colors from Matugen palette
PRIMARY=$(jq -r '.colors.dark.primary // "#8dcff2"' "$PALETTE_JSON")
SECONDARY=$(jq -r '.colors.dark.secondary // "#b5cad7"' "$PALETTE_JSON")
FOREGROUND=$(jq -r '.colors.dark.on_background // "#dfe3e7"' "$PALETTE_JSON")

# Fallbacks
PRIMARY=${PRIMARY:-#8dcff2}
SECONDARY=${SECONDARY:-#b5cad7}
FOREGROUND=${FOREGROUND:-#dfe3e7}

# Generate Fastfetch config
cat > "$FASTFETCH_CONF" <<EOF
# Fastfetch color theme from Matugen

# Heading color (titles)
color1=$PRIMARY

# Info color (values)
color2=$SECONDARY

# Optional: you can also set accents for bars/logos
accent_color=$FOREGROUND
EOF
