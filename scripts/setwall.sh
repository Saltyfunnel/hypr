#!/bin/bash
# setwall.sh - Sets wallpaper + Pywal + updates Waybar, Yazi, Tofi
set -euo pipefail

# ----------------------------
# Directories
# ----------------------------
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WAYBAR_CSS="$HOME/.config/waybar/style.css"
PYWAL_CACHE="$HOME/.cache/wal/colors.css"
YAZI_THEME="$HOME/.config/yazi/theme.toml"

# ----------------------------
# Start swww-daemon if needed
# ----------------------------
if ! pgrep -x "swww-daemon" >/dev/null; then
    swww-daemon &
    sleep 1
fi

# ----------------------------
# Pick a random wallpaper if not provided
# ----------------------------
if [[ -z "${1-}" ]]; then
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" \) | shuf -n 1)
else
    WALLPAPER="$1"
fi

if [[ -z "$WALLPAPER" ]]; then
    echo "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# ----------------------------
# Set wallpaper
# ----------------------------
swww img "$WALLPAPER" --transition-type any --transition-step 90 --transition-fps 60

# ----------------------------
# Generate Pywal colors
# ----------------------------
wal -n -q -i "$WALLPAPER"
sleep 0.5

# ----------------------------
# Read colors
# ----------------------------
declare -A COLORS
for i in {0..15}; do
    COLORS[$i]=$(grep "color$i" "$PYWAL_CACHE" | grep -o '#[0-9A-Fa-f]\{6\}' | head -n1)
done

BG=${COLORS[0]}
FG=${COLORS[7]}

# Standard modules
cat > "$WAYBAR_CSS" <<EOF
/* Waybar CSS - Pywal colors applied */
@define-color color0 ${COLORS[0]};
@define-color color1 ${COLORS[1]};
@define-color color2 ${COLORS[2]};
@define-color color3 ${COLORS[3]};
@define-color color4 ${COLORS[4]};
@define-color color5 ${COLORS[5]};
@define-color color6 ${COLORS[6]};
@define-color color7 ${COLORS[7]};
@define-color color8 ${COLORS[8]};
@define-color color9 ${COLORS[9]};
@define-color color10 ${COLORS[10]};
@define-color color11 ${COLORS[11]};
@define-color color12 ${COLORS[12]};
@define-color color13 ${COLORS[13]};
@define-color color14 ${COLORS[14]};
@define-color color15 ${COLORS[15]};

* {
    font-family: "FiraCode Nerd Font";
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background-color: transparent;
    color: @color7;
    border: none;
    transition: background-color 0.3s;
}

/* Modules container */
.modules-left,
.modules-center,
.modules-right {
    background-color: transparent;
    border-radius: 0;
    margin: 0;
    padding: 0;
}

/* Module boxes */
#window,
#clock,
#custom-spotify,
#custom-firefox,
#custom-steam,
#custom-screenshot,
#cpu,
#battery,
#backlight,
#memory,
#network,
#pulseaudio,
#pulseaudio#microphone,
#custom-power,
#tray,
#workspaces {
    background-color: rgba(15, 15, 15, 0.8);
    border-radius: 10px;
    margin: 3px;
    padding: 5px 10px;
    transition: all 0.3s ease;
}

/* Module text colors */
#window { color: @color5; }
#clock { color: @color3; }
#cpu { color: @color2; }
#battery { color: @color5; }
#backlight { color: @color2; }
#memory { color: @color4; }
#network { color: @color6; }
#pulseaudio { color: @color1; }
#pulseaudio#microphone { color: @color9; }
#custom-power { color: @color3; }
#tray { color: @color7; }

/* Individual App Colors */
#custom-spotify { color: @color2; }
#custom-firefox { color: @color3; }
#custom-steam { color: @color4; }
#custom-screenshot { color: @color12; }

/* Hover glow — safe syntax */
#custom-spotify:hover {
    box-shadow: 0 0 8px @color2;
    background-color: rgba(255, 255, 255, 0.05);
}
#custom-firefox:hover {
    box-shadow: 0 0 8px @color3;
    background-color: rgba(255, 255, 255, 0.05);
}
#custom-steam:hover {
    box-shadow: 0 0 8px @color4;
    background-color: rgba(255, 255, 255, 0.05);
}

/* Workspaces */
#workspaces button {
    background-color: transparent;
    color: @color2;
    border: none;
    margin: 0 3px;
    padding: 0 6px;
}

#workspaces button.active {
    background-color: rgba(255, 255, 255, 0.1);
    border-radius: 6px;
}

#workspaces button:hover {
    background-color: rgba(255, 255, 255, 0.08);
}
EOF

# ----------------------------
# Generate Pywal-themed Dunst config
# ----------------------------
DUNST_CONFIG="$HOME/.config/dunst/dunstrc"
mkdir -p "$(dirname "$DUNST_CONFIG")"

# Extract colors reliably from Pywal16 CSS
declare -A COLORS
for i in {0..15}; do
    COLORS[$i]=$(sed -n "s/.*--color$i: \(#[0-9a-fA-F]\{6\}\);.*/\1/p" "$PYWAL_CACHE")
done

# Default values fallback
BG=${COLORS[0]:-"#1c1c1c"}
FG=${COLORS[7]:-"#dcdccc"}
FRAME=${COLORS[2]:-"#000000"}
CRIT_BG=${COLORS[9]:-"#ff5555"}
CRIT_FG=${COLORS[0]:-"#1c1c1c"}

cat > "$DUNST_CONFIG" <<EOF
[global]
font = FiraCode Nerd Font 12
frame_width = 2
separator_height = 2
padding = 8
horizontal_padding = 10
vertical_padding = 10
geometry = 350x90
icon_position = left
image = yes
shrink = true
transparency = 0
frame_color = "$FRAME"

[urgency_low]
timeout = 3
background = "$BG"
foreground = "$FG"

[urgency_normal]
timeout = 5
background = "$BG"
foreground = "$FG"

[urgency_critical]
timeout = 0
background = "$CRIT_BG"
foreground = "$CRIT_FG"
EOF

# Reload Dunst to apply new colors
pkill dunst
dunst &


# Reload Waybar
pkill -USR2 waybar || waybar &

# ----------------------------
# Update Yazi theme
# ----------------------------
mkdir -p "$(dirname "$YAZI_THEME")"
cat > "$YAZI_THEME" <<EOF
[mgr]
fg = "$FG"
bg = "$BG"
border = "${COLORS[2]}"
highlight = "${COLORS[4]}"

[statusbar]
fg = "$FG"
bg = "$BG"

[preview]
fg = "$FG"
bg = "$BG"
EOF
