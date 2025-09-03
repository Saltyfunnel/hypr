#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/.config/assets/wallpapers"
FASTFETCH_CONFIG="$HOME/.config/fastfetch/config.json"
DUNST_CONFIG="$HOME/.config/dunst/dunstrc"
WAYBAR_CONFIG="$HOME/.config/waybar/config"
KITTY_CONFIG="$HOME/.config/kitty/kitty.conf"
TOFI_CONFIG="$HOME/.config/tofi/configA"

log() { echo -e "\033[0;34m[wallpaper-theme]\033[0m $1"; }

log "Launching Waypaper interactive selection..."
waypaper --folder "$WALL_DIR" fill

# Get currently applied wallpaper path from Waypaper state file
STATE_FILE="${HOME}/.config/waypaper/state.json"
if [[ -f "$STATE_FILE" ]]; then
    WALL=$(jq -r '.wallpaper' "$STATE_FILE")
    log "Selected wallpaper: $WALL"
else
    log "Waypaper state file not found. Pywal theming skipped."
    exit 1
fi

# Apply Pywal
if command -v wal &>/dev/null; then
    wal -i "$WALL" -q -n
    log "Pywal colors generated"
else
    log "Pywal not installed, skipping theming"
fi

# Theme Fastfetch
if [[ -f "$FASTFETCH_CONFIG" && -f "$HOME/.cache/wal/colors.json" ]]; then
    ACCENT=$(jq -r '.colors.color2' "$HOME/.cache/wal/colors.json")
    jq --arg accent "$ACCENT" '(.modules[] | select(.keyColor) | .keyColor) |= $accent' \
        "$FASTFETCH_CONFIG" > "$FASTFETCH_CONFIG.tmp" && mv "$FASTFETCH_CONFIG.tmp" "$FASTFETCH_CONFIG"
    log "Fastfetch themed"
fi

# Theme Dunst
if [[ -f "$DUNST_CONFIG" ]]; then
    COLOR=$(xrdb -query | grep '*color2:' | awk '{print $2}' || echo "#ffffff")
    sed -i "s/^frame_color = .*/frame_color = \"$COLOR\"/" "$DUNST_CONFIG"
    pkill -USR1 dunst || true
    log "Dunst themed"
fi

# Restart Waybar
systemctl --user restart waybar || log "Waybar restarted"
log "Waybar themed"

# Theme Kitty
if [[ -f "$KITTY_CONFIG" ]]; then
    kitty @ set-colors --all --config-file "$KITTY_CONFIG" || true
    log "Kitty themed"
fi

# Reload Tofi
if [[ -f "$TOFI_CONFIG" ]]; then
    pkill -USR1 tofi || true
    log "Tofi themed"
fi

log "Done!"
