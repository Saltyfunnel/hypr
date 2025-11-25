#!/usr/bin/env bash

DIR="$HOME/Pictures/Screenshots"
DATE="$(date +'%Y-%m-%d_%H-%M-%S')"
FILE="$DIR/screenshot_$DATE.png"

mkdir -p "$DIR"

notify() {
    notify-send "Screenshot" "$1" -i "$FILE"
}

case "$1" in
    area)
        grim -g "$(slurp)" "$FILE" && notify "Area captured → Saved"
        ;;
    window)
        active=$(hyprctl -j activewindow | jq -r '.at,.size' | tr '\n' ' ')
        grim -g "$active" "$FILE" && notify "Window captured → Saved"
        ;;
    screen)
        grim "$FILE" && notify "Screen captured → Saved"
        ;;
    *)
        notify-send "Screenshot" "Usage: $0 {area|window|screen}"
        exit 1
        ;;
esac
