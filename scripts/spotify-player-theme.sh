#!/usr/bin/env bash
set -euo pipefail

COLORS_JSON="$HOME/.cache/wal/colors.json"
THEME_FILE="$HOME/.config/spotify-player/theme.toml"

bg=$(jq -r '.special.background' "$COLORS_JSON")
fg=$(jq -r '.special.foreground' "$COLORS_JSON")
c0=$(jq -r '.colors.color0' "$COLORS_JSON")
c1=$(jq -r '.colors.color1' "$COLORS_JSON")
c2=$(jq -r '.colors.color2' "$COLORS_JSON")
c3=$(jq -r '.colors.color3' "$COLORS_JSON")
c4=$(jq -r '.colors.color4' "$COLORS_JSON")
c5=$(jq -r '.colors.color5' "$COLORS_JSON")
c6=$(jq -r '.colors.color6' "$COLORS_JSON")
c7=$(jq -r '.colors.color7' "$COLORS_JSON")
c8=$(jq -r '.colors.color8' "$COLORS_JSON")
c15=$(jq -r '.colors.color15' "$COLORS_JSON")

cat > "$THEME_FILE" <<EOF
[[themes]]
name = "pywal"

[themes.palette]
background = "$bg"
foreground = "$fg"
black = "$c0"
red = "$c1"
green = "$c2"
yellow = "$c3"
blue = "$c4"
magenta = "$c5"
cyan = "$c6"
white = "$c7"
bright_black = "$c8"
bright_red = "$c1"
bright_green = "$c2"
bright_yellow = "$c3"
bright_blue = "$c4"
bright_magenta = "$c5"
bright_cyan = "$c6"
bright_white = "$c15"
EOF
