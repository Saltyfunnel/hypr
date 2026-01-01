#!/bin/bash
# ~/.config/scripts/startyazi.sh

# 1. Load Pywal colors into the terminal session
if [[ -f "$HOME/.cache/wal/sequences" ]]; then
    cat "$HOME/.cache/wal/sequences"
fi

# 2. Force the Terminal variable
# This tells Yazi "You are definitely in Kitty, use the graphics protocol!"
export TERM=xterm-kitty

# 3. Launch Yazi
yazi "$@"
