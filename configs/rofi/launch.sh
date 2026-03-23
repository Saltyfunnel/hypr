#!/bin/bash
WALL=$(cat ~/.cache/wal/wal)
BG=$(grep "^    background:" ~/.cache/wal/colors-rofi-dark.rasi | awk '{print $2}' | tr -d ';#')

sed -i "s|background-image:.*|background-image:            url(\"$WALL\", height);|" ~/.config/rofi/launcher.rasi
sed -i "s|background-color:.*\/\* window-bg \*\/|background-color:            #DD${BG}; /* window-bg */|" ~/.config/rofi/launcher.rasi

rofi -show drun -theme ~/.config/rofi/launcher.rasi
