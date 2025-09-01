#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helper.sh"

log_message "Installation started for utilities section"
print_info "\nStarting utilities setup..."

# Detect the user running sudo (or fallback to current user)
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USER_NAME")

CONFIG_DIR="$USER_HOME/.config"
REPO_DIR="$USER_HOME/hyprbw"
ASSETS_SRC="$REPO_DIR/assets"
ASSETS_DEST="$CONFIG_DIR/assets"

copy_as_user() {
    local src="$1"
    local dest="$2"

    if [ ! -d "$src" ]; then
        print_warning "Source folder not found: $src"
        return 1
    fi

    run_command "mkdir -p \"$dest\"" "Create destination directory $dest" "no" "no"
    run_command "cp -r \"$src\"/* \"$dest\"" "Copy from $src to $dest" "yes" "no"
    run_command "chown -R $USER_NAME:$USER_NAME \"$dest\"" "Fix ownership for $dest" "no" "yes"
}

# Install core utilities
run_command "pacman -S --noconfirm waybar" "Install Waybar" "yes"
copy_as_user "$REPO_DIR/configs/waybar" "$CONFIG_DIR/waybar"

run_command "yay -S --sudoloop --noconfirm tofi fastfetch swww hyprpicker hyprlock grimblast hypridle starship" "Install AUR utilities" "yes" "no"

copy_as_user "$REPO_DIR/configs/tofi" "$CONFIG_DIR/tofi"
copy_as_user "$REPO_DIR/configs/fastfetch" "$CONFIG_DIR/fastfetch"
copy_as_user "$REPO_DIR/configs/hypr" "$CONFIG_DIR/hypr"

# Add fastfetch to shells
add_fastfetch_to_shell() {
    local shell_rc="$1"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local fastfetch_line='fastfetch --kitty-direct /home/'"$USER_NAME"'/.config/fastfetch/archkitty.png'

    if [ -f "$shell_rc_path" ] && ! grep -qF "$fastfetch_line" "$shell_rc_path"; then
        echo -e "\n# Run fastfetch on terminal start\n$fastfetch_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

add_fastfetch_to_shell ".bashrc"
add_fastfetch_to_shell ".zshrc"

run_command "pacman -S --noconfirm cliphist" "Install Cliphist" "yes"

copy_as_user "$ASSETS_SRC/backgrounds" "$ASSETS_DEST/backgrounds"

# Starship config
STARSHIP_SRC="$REPO_DIR/configs/starship/starship.toml"
STARSHIP_DEST="$CONFIG_DIR/starship.toml"

if [ -f "$STARSHIP_SRC" ]; then
    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
    chown "$USER_NAME:$USER_NAME" "$STARSHIP_DEST"
fi

add_starship_to_shell() {
    local shell_rc="$1"
    local shell_name="$2"
    local shell_rc_path="$USER_HOME/$shell_rc"
    local starship_line='eval "$(starship init '"$shell_name"')"'

    if [ -f "$shell_rc_path" ] && ! grep -qF "$starship_line" "$shell_rc_path"; then
        echo -e "\n$starship_line" >> "$shell_rc_path"
        chown "$USER_NAME:$USER_NAME" "$shell_rc_path"
    fi
}

add_starship_to_shell ".bashrc" "bash"
add_starship_to_shell ".zshrc" "zsh"

# Papirus icons and folder coloring
run_command "pacman -S --noconfirm papirus-icon-theme" "Install Papirus Icon Theme" "yes"

if ! command -v papirus-folders &>/dev/null; then
    TMP_DIR=$(mktemp -d)
    git clone https://github.com/PapirusDevelopmentTeam/papirus-folders.git "$TMP_DIR"
    install -Dm755 "$TMP_DIR/papirus-folders" /usr/local/bin/papirus-folders
    rm -rf "$TMP_DIR"
fi

sudo -u "$USER_NAME" dbus-launch papirus-folders -C grey --theme Papirus-Dark

# GTK theming
GTK3_CONFIG_DIR="$USER_HOME/.config/gtk-3.0"
GTK4_CONFIG_DIR="$USER_HOME/.config/gtk-4.0"

mkdir -p "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"

GTK_SETTINGS_CONTENT="[Settings]
gtk-theme-name=FlatColor
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono 10"

echo "$GTK_SETTINGS_CONTENT" | sudo -u "$USER_NAME" tee "$GTK3_CONFIG_DIR/settings.ini" "$GTK4_CONFIG_DIR/settings.ini" >/dev/null
chown -R "$USER_NAME:$USER_NAME" "$GTK3_CONFIG_DIR" "$GTK4_CONFIG_DIR"

sudo -u "$USER_NAME" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'

# SDDM theming
MONO_SDDM_REPO="https://github.com/pwyde/monochrome-kde.git"
MONO_SDDM_TEMP="/tmp/monochrome-kde"
MONO_THEME_NAME="monochrome"

git clone --depth=1 "$MONO_SDDM_REPO" "$MONO_SDDM_TEMP"
cp -r "$MONO_SDDM_TEMP/sddm/themes/$MONO_THEME_NAME" "/usr/share/sddm/themes/$MONO_THEME_NAME"
chown -R root:root "/usr/share/sddm/themes/$MONO_THEME_NAME"
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=$MONO_THEME_NAME" > /etc/sddm.conf.d/10-theme.conf
rm -rf "$MONO_SDDM_TEMP"

# Thunar Kitty custom action
setup_thunar_kitty_action() {
  local uca_dir="$CONFIG_DIR/Thunar"
  local uca_file="$uca_dir/uca.xml"

  mkdir -p "$uca_dir"
  chown "$USER_NAME:$USER_NAME" "$uca_dir"
  chmod 700 "$uca_dir"

  local kitty_action_xml='
  <action>
    <icon>utilities-terminal</icon>
    <name>Open Kitty Here</name>
    <command>kitty --directory=%d</command>
    <description>Open kitty terminal in the current folder</description>
    <patterns>*</patterns>
    <directories_only>true</directories_only>
    <startup_notify>true</startup_notify>
  </action>'

  if [ ! -f "$uca_file" ]; then
    cat > "$uca_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<actions>
$kitty_action_xml
</actions>
EOF
    chown "$USER_NAME:$USER_NAME" "$uca_file"
  else
    if ! grep -q "<name>Open Kitty Here</name>" "$uca_file"; then
      sed -i "/<\/actions>/ i\\
$kitty_action_xml
" "$uca_file"
      chown "$USER_NAME:$USER_NAME" "$uca_file"
    fi
  fi
}

setup_thunar_kitty_action

print_success "\nUtilities setup complete!"
