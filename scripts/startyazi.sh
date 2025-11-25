#!/bin/bash
# ~/.config/scripts/start_yazi.sh

# Load Pywal colors into terminal
if [[ -f "$HOME/.cache/wal/sequences" ]]; then
    cat "$HOME/.cache/wal/sequences"
fi

# Launch Yazi
yazi
