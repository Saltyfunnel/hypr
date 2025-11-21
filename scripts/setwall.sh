#!/bin/bash
# setwall.sh - Sets wallpaper + Pywal + updates Waybar, Yazi, Mako + screenshot notifications
set -euo pipefail

# ----------------------------
# Directories
# ----------------------------
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
WAYBAR_CSS="$HOME/.config/waybar/style.css"
WAYBAR_CONFIG="$HOME/.config/waybar/config"
PYWAL_CACHE="$HOME/.cache/wal/colors.css"
YAZI_THEME="$HOME/.config/yazi/theme.toml"
MAKO_CONFIG="$HOME/.config/mako/config"
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
SCREENSHOT_SCRIPT="$HOME/.local/bin/screenshot_notify.sh"

mkdir -p "$SCREENSHOT_DIR"
mkdir -p "$(dirname "$SCREENSHOT_SCRIPT")"

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

# ----------------------------
# Update Waybar CSS
# ----------------------------
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

/* Hover glow */
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

# Reload Waybar
pkill -USR2 waybar || waybar &

# ----------------------------
# Generate Pywal-themed Mako config
# ----------------------------
mkdir -p "$(dirname "$MAKO_CONFIG")"

BG_MAKO=${COLORS[0]:-"#1c1c1c"}
FG_MAKO=${COLORS[7]:-"#dcdccc"}
BORDER_MAKO=${COLORS[2]:-"#000000"}
CRIT_BG=${COLORS[9]:-"#ff5555"}
CRIT_FG=${COLORS[0]:-"#1c1c1c"}

cat > "$MAKO_CONFIG" <<EOF
# Mako Configuration - Pywal Colors
anchor=top-right
width=350
height=90
margin=10
padding=8
border-size=2
border-radius=10

font=FiraCode Nerd Font 12
text-color=${FG_MAKO}
background-color=${BG_MAKO}
border-color=${BORDER_MAKO}
default-timeout=5000

[urgency=low]
background-color=${BG_MAKO}
text-color=${FG_MAKO}
default-timeout=3000

[urgency=normal]
background-color=${BG_MAKO}
text-color=${FG_MAKO}
default-timeout=5000

[urgency=critical]
background-color=${CRIT_BG}
text-color=${CRIT_FG}
default-timeout=0
EOF

# Reload Mako
pkill mako
mako &

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

# ----------------------------
# Screenshot helper (sends notifications)
# ----------------------------
cat > "$SCREENSHOT_SCRIPT" <<'EOS'
#!/bin/bash
DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot_$(date +%F_%T).png"

case "$1" in
    area)
        grim -g "$(slurp)" "$FILE"
        ;;
    window)
        RECT=$(hyprctl activewindow -j | jq -r '.at | "\(.x),\(.y) \(.width)x\(.height)"')
        grim -g "$RECT" "$FILE"
        ;;
    screen)
        grim "$FILE"
        ;;
    *)
        grim "$FILE"
        ;;
esac

notify-send "Screenshot saved" "$FILE"
EOS
chmod +x "$SCREENSHOT_SCRIPT"


# ----------------------------
# Finished
# ----------------------------
notify-send "Wallpaper & Theme" "✅ Waybar, Mako, and Yazi updated!"
echo "✅ setwall.sh complete!"
