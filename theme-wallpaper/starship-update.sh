#!/bin/bash
# Updates Starship config using Matugen palette

PALETTE_JSON="$HOME/.config/theme-wallpaper/palette.json"
STARSHIP_CONF="$HOME/.config/starship.toml"

# Extract colors from Matugen palette
PRIMARY=$(jq -r '.colors.dark.primary // "#8dcff2"' "$PALETTE_JSON")
SECONDARY=$(jq -r '.colors.dark.secondary // "#b5cad7"' "$PALETTE_JSON")
FOREGROUND=$(jq -r '.colors.dark.on_background // "#dfe3e7"' "$PALETTE_JSON")

# Fallbacks
PRIMARY=${PRIMARY:-#8dcff2}
SECONDARY=${SECONDARY:-#b5cad7}
FOREGROUND=${FOREGROUND:-#dfe3e7}

# Generate Starship config
cat > "$STARSHIP_CONF" <<EOF
# Starship prompt themed from Matugen

[directory]
style = "bold $PRIMARY"

[hostname]
style = "bold $SECONDARY"

[git_branch]
style = "bold $PRIMARY"

[git_state]
style = "bold $SECONDARY"

[git_status]
style = "bold $FOREGROUND"

[character]
success_symbol = "➜"
error_symbol = "✗"
vicmd_symbol = "❮"
style = "bold #8dcff2"  # example: your primary color

EOF
