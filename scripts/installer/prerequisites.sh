#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get original user running sudo
SUDO_USER=$(logname)
USER_HOME="/home/$SUDO_USER"
REPO_DIR="$USER_HOME/hypr"
BASHRC_PATH="$USER_HOME/.bashrc"

echo -e "\nStarting prerequisites setup..."

echo "Updating package database and upgrading packages..."
pacman -Syyu --noconfirm

# --- Yay Installation ---
if ! command -v yay &> /dev/null; then
    echo "YAY not found, installing..."

    pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    chown -R $SUDO_USER:$SUDO_USER /tmp/yay
    cd /tmp/yay
    sudo -u $SUDO_USER makepkg -si --noconfirm
    cd -
    rm -rf /tmp/yay
else
    echo "YAY is already installed."
fi

# --- System Packages ---
pacman -S --noconfirm pipewire wireplumber pamixer brightnessctl

pacman -S --noconfirm ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-firacode-nerd ttf-iosevka-nerd ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd ttf-jetbrains-mono ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono

pacman -S --noconfirm sddm && systemctl enable sddm.service

# --- Firefox Instead of Brave ---
yay -S --noconfirm firefox

# --- Terminal, Editor, Tools ---
pacman -S --noconfirm kitty nano tar nautilus

echo "------------------------------------------------------------------------"

# --- Install fastfetch, starship ---
yay -S --noconfirm fastfetch starship

# --- Starship Setup ---
if ! grep -q "starship init" "$BASHRC_PATH"; then
  cat << 'EOF' >> "$BASHRC_PATH"

# Initialize Starship prompt
eval "$(starship init bash)"
EOF
  echo "✅ Added Starship prompt initialization to $BASHRC_PATH"
else
  echo "ℹ️ Starship prompt initialization already present, skipping."
fi

# --- fastfetch on login ---
if ! grep -q "^fastfetch$" "$BASHRC_PATH"; then
  echo -e "\n# Run fastfetch on terminal start\nfastfetch" >> "$BASHRC_PATH"
  echo "✅ Added fastfetch command to $BASHRC_PATH"
else
  echo "ℹ️ fastfetch command already present, skipping."
fi

# --- Copy Catppuccin config files ---
if [ -d "$REPO_DIR/configs" ]; then
  echo "Copying Catppuccin config files from $REPO_DIR/configs to $USER_HOME/.config/"

  sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/starship"
  sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/fastfetch"

  sudo -u "$SUDO_USER" cp -rv "$REPO_DIR/configs/"* "$USER_HOME/.config/"

  echo "✅ Catppuccin theme config files copied."
else
  echo "⚠️ Configs directory $REPO_DIR/configs not found. Skipping config copy."
fi

echo "👉 Please reload your shell or run: source $BASHRC_PATH"
