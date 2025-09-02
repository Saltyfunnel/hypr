#!/bin/bash
# Ensure proper Wayland environment
export XDG_SESSION_TYPE=wayland
export WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
export XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"

# Launch Yazi as the current user
sudo -u "$USER" setsid yazi >/dev/null 2>&1 &
