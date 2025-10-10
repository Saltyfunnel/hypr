# ====================================================================
# PYWAL FIX: Load ANSI Color Variables for Starship
# ====================================================================
if [ -f "$HOME/.cache/wal/colors.sh" ]; then
    . "$HOME/.cache/wal/colors.sh"
fi

# Optional: restore terminal background
if [ -f "$HOME/.cache/wal/sequences" ]; then
    cat "$HOME/.cache/wal/sequences"
fi

# Only do the rest for interactive shells
[[ $- != *i* ]] && return

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# Initialize Starship prompt (after colors.sh)
eval "$(starship init bash)"

# Optional: clear screen and show system info once
clear
fastfetch
