#!/bin/bash
walfile="$HOME/.cache/wal/colors.json"
cssfile="$HOME/.config/waybar/style.css"

# fallback colors
fg=$(jq -r '.colors.foreground // "#ffffff"' "$walfile")
bg=$(jq -r '.colors.background // "#1e1e2e"' "$walfile")
color1=$(jq -r '.colors.color1 // "#ff5555"' "$walfile")
color2=$(jq -r '.colors.color2 // "#50fa7b"' "$walfile")
color3=$(jq -r '.colors.color3 // "#f1fa8c"' "$walfile")
color4=$(jq -r '.colors.color4 // "#bd93f9"' "$walfile")
color5=$(jq -r '.colors.color5 // "#ff79c6"' "$walfile")
color6=$(jq -r '.colors.color6 // "#8be9fd"' "$walfile")
color7=$(jq -r '.colors.color7 // "#bbbbbb"' "$walfile")

cat > "$cssfile" <<EOL
* {
    font-family: JetBrainsMono, sans-serif;
    font-size: 14px;
    color: $fg;
}

window#waybar {
    background-color: $bg;
    border-bottom: 2px solid $color4;
    padding: 3px 10px;
}

#workspaces button {
    padding: 0 10px;
    color: $color3;
    border-radius: 4px;
}

#workspaces button.focused {
    background-color: $color4;
    color: $bg;
}

#network { color: $color2; }
#battery { color: $color1; }
#pulseaudio { color: $color2; }
#clock { color: $color7; }
#cpu { color: $color5; }
#memory { color: $color6; }

#network:hover,
#battery:hover,
#pulseaudio:hover,
#cpu:hover,
#memory:hover {
    color: $color4;
}
EOL

