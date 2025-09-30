# Disable instant prompt to allow Pywal + Fastfetch to theme terminal
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

# Powerlevel10k
if [ -f /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme ]; then
  source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
fi
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Restore Pywal colors
wal -r

# Clear screen
clear

# Run Fastfetch
fastfetch
cd
