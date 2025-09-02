#!/bin/bash
ROFI_TEMPLATE="$HOME/.config/rofi/config-template.rasi"
ROFI_CONFIG="$HOME/.config/rofi/config.rasi"
WAL_CSS="$HOME/.cache/wal/colors.css"

BACKGROUND=$(awk -F: '/background/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CSS")
FOREGROUND=$(awk -F: '/foreground/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CSS")
COLOR0=$(awk -F: '/color0/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CSS")
COLOR1=$(awk -F: '/color1/ {gsub(/[ ;]/,"",$2); print $2}' "$WAL_CSS")

BACKGROUND=${BACKGROUND:-"#222222"}
FOREGROUND=${FOREGROUND:-"#eeeeee"}
COLOR0=${COLOR0:-"#444444"}
COLOR1=${COLOR1:-"#ff5555"}

sed -e "s/@background/$BACKGROUND/g" \
    -e "s/@foreground/$FOREGROUND/g" \
    -e "s/@color0/$COLOR0/g" \
    -e "s/@color1/$COLOR1/g" \
    "$ROFI_TEMPLATE" > "$ROFI_CONFIG"
