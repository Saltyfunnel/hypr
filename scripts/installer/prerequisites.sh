#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helper.sh"

log_message "Installation started for prerequisites section"
print_info "\nStarting prerequisites setup..."

run_command "pacman -Syyu --noconfirm" "Update package database and upgrade packages (Recommended)" "yes"

# --- Yay Installation ---
if ! command -v yay &> /dev/null; then
    print_info "YAY not found, installing..."

    run_command "pacman -S --noconfirm --needed git base-devel" "Install Git and base-devel for yay" "yes"
    run_command "git clone https://aur.archlinux.org/yay.git /tmp/yay" "Clone yay repo" "no" "no"
    run_command "chown -R $SUDO_USER:$SUDO_USER /tmp/yay" "Fix yay folder ownership" "no" "no"
    run_command "cd /tmp/yay && sudo -u $SUDO_USER makepkg -si --noconfirm" "Build and install yay" "no" "no"
    run_command "rm -rf /tmp/yay" "Clean up yay build folder" "no" "no"
else
    print_success "YAY is already installed."
fi

# --- System Packages ---
run_command "pacman -S --noconfirm pipewire wireplumber pamixer brightnessctl" "Configuring audio and brightness (Recommended)" "yes"

run_command "pacman -S --noconfirm ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-firacode-nerd ttf-iosevka-nerd ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd ttf-jetbrains-mono ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono" "Installing Nerd Fonts and Symbols (Recommended)" "yes"

run_command "pacman -S --noconfirm sddm && systemctl enable sddm.service" "Install and enable SDDM (Recommended)" "yes"

# --- Firefox Instead of Brave ---
run_command "yay -S --sudoloop --noconfirm firefox" "Install Firefox browser" "yes" "no"

# --- Terminal, Editor, Tools ---
run_command "pacman -S --noconfirm kitty nano tar nautilus" "Install Kitty, nano, tar, Nautilus" "yes"

echo "------------------------------------------------------------------------"

# --- Install fastfetch, starship ---
run_command "yay -S --noconfirm fastfetch starship" "Install fastfetch, starship" "yes"

BASHRC_PATH="/home/$SUDO_USER/.bashrc"
USER_HOME="/home/$SUDO_USER"

# Repo directory path
REPO_DIR="/home/$SUDO_USER/hypr"

print_info "DEBUG: Configs directory resolved to: $REPO_DIR/configs"

# --- Starship Setup ---
if ! grep -q "starship init" "$BASHRC_PATH"; then
  cat << 'EOF' >> "$BASHRC_PATH"

# Initialize Starship prompt
eval "$(starship init bash)"
EOF
  echo "✅ Added Starship prompt initialization to $BASHRC_PATH"
else
  echo "ℹ️ Starship prompt initialization already present in $BASHRC_PATH, skipping append."
fi

# --- fastfetch on login ---
if ! grep -q "^fastfetch$" "$BASHRC_PATH"; then
  echo -e "\n# Run fastfetch on terminal start\nfastfetch" >> "$BASHRC_PATH"
  echo "✅ Added fastfetch command to $BASHRC_PATH"
else
  echo "ℹ️ fastfetch command already present in $BASHRC_PATH, skipping."
fi

# --- Copy Catppuccin config files ---
if [ -d "$REPO_DIR/configs" ]; then
  echo "📁 Copying Catppuccin config files from $REPO_DIR/configs to $USER_HOME/.config/"

  sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/starship"
  sudo -u "$SUDO_USER" mkdir -p "$USER_HOME/.config/fastfetch"

  echo "Debug: listing starship config before copy:"
  ls -l "$REPO_DIR/configs/starship/starship.toml"

  sudo -u "$SUDO_USER" cp -rv "$REPO_DIR/configs/"* "$USER_HOME/.config/"

  echo "Debug: listing starship config after copy:"
  ls -l "$USER_HOME/.config/starship/starship.toml"

  echo "✅ Catppuccin theme config files copied."
else
  echo "⚠️ Configs directory $REPO_DIR/configs not found. Skipping Catppuccin config copy."
fi

echo "👉 Please reload your shell or run: source $BASHRC_PATH"
