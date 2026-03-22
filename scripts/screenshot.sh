#!/usr/bin/env bash
DIR="$HOME/Pictures/Screenshots"
DATE="$(date +'%Y-%m-%d_%H-%M-%S')"
FILE="$DIR/screenshot_$DATE.png"
DELAY=3  # Default delay in seconds for full screen

mkdir -p "$DIR"

notify() {
    notify-send "Screenshot" "$1" -i "$FILE"
}

countdown() {
    local seconds=$1
    for ((i=seconds; i>0; i--)); do
        notify-send -u critical -t 950 "Screenshot in $i..."
        sleep 1
    done
}

case "$1" in
    area)
        grim -g "$(slurp)" "$FILE" && notify "Area captured → Saved"
        ;;
    window)
        # Get window position and size, format as "X,Y WIDTHxHEIGHT"
        active=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        grim -g "$active" "$FILE" && notify "Window captured → Saved"
        ;;
    screen)
        countdown $DELAY
        grim "$FILE" && notify "Screen captured → Saved"
        ;;
    screen-nodelay)
        grim "$FILE" && notify "Screen captured → Saved"
        ;;
    *)
        notify-send "Screenshot" "Usage: $0 {area|window|screen|screen-nodelay}"
        exit 1
        ;;
esac
