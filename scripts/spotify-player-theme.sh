#!/usr/bin/env bash
# Syncs spotify_player's pywal theme palette + component styling to the current wallpaper colors.

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

[themes.component_style]
block_title = { fg = "$c4", modifiers = ["Bold"] }
border = { fg = "$c8" }
playback_status = { fg = "$c4", modifiers = ["Bold"] }
playback_track = { fg = "$fg", modifiers = ["Bold"] }
playback_artists = { fg = "$c4", modifiers = ["Bold"] }
playback_album = { fg = "$c3" }
playback_genres = { fg = "$c8", modifiers = ["Italic"] }
playback_metadata = { fg = "$c8" }
playback_progress_bar = { bg = "$c8", fg = "$c4" }
playback_progress_bar_unfilled = { bg = "$c0" }
current_playing = { fg = "$c2", modifiers = ["Bold"] }
page_desc = { fg = "$c4", modifiers = ["Bold"] }
playlist_desc = { fg = "$c8", modifiers = ["Dim"] }
table_header = { fg = "$c4" }
selection = { fg = "$bg", bg = "$c4", modifiers = ["Bold"] }
secondary_row = {}
like = { fg = "$c1" }
lyrics_played = { modifiers = ["Dim"] }
lyrics_playing = { fg = "$c2", modifiers = ["Bold"] }
EOF
