#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# SUDO_USER is exported by install.sh
# USER_HOME="/home/$SUDO_USER" # Not strictly needed if using relative paths below
BASHRC_PATH="/home/$SUDO_USER/.bashrc" # Still needs SUDO_USER for home path

# Define consistent relative paths based on script location
# Assumes 'configs' and 'assets' are sibling directories to 'scripts'
CONFIGS_DIR="$SCRIPT_DIR/../configs"
ASSETS_DIR="$SCRIPT_DIR/../assets"

source "$SCRIPT_DIR/helper.sh" # Source helper after SCRIPT_DIR is set

log_message "Starting prerequisites setup"
print_info "\nStarting prerequisites setup..."

echo "Updating package database and upgrading packages..."
pacman -Syyu --noconfirm

# --- Yay Installation ---
if ! command -v yay &> /dev/null; then
    echo "YAY not found, installing..."

    pacman -S --noconfirm --needed git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    chown -R $SUDO_USER:$SUDO_USER /tmp/yay
    cd /tmp/yay
    # Use run_command for makepkg for consistency and logging
    run_command "makepkg -si --noconfirm" "Build and install Yay" "yes" "no" # 'no' for use_sudo
    cd -
    rm -rf /tmp/yay
else
    echo "YAY is already installed."
fi

# --- System Packages ---
run_command "pacman -S --noconfirm pipewire wireplumber pamixer brightnessctl" "Install basic system utilities" "yes"
run_command "pacman -S --noconfirm ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-firacode-nerd ttf-iosevka-nerd ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd ttf-jetbrains-mono ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono" "Install Nerd Fonts" "yes"

run_command "pacman -S --noconfirm sddm" "Install SDDM display manager" "yes"
run_command "systemctl enable sddm.service" "Enable SDDM service" "yes"

# --- Firefox Instead of Brave ---
run_command "yay -S --noconfirm firefox" "Install Firefox browser" "yes" "no"

# --- Terminal, Editor, Tools ---
run_command "pacman -S --noconfirm kitty nano tar nautilus" "Install Kitty, Nano, Tar, Nautilus" "yes"

echo "------------------------------------------------------------------------"

# --- Install fastfetch, starship ---
run_command "yay -S --noconfirm fastfetch starship" "Install Fastfetch and Starship" "yes" "no"

# --- Starship Setup ---
if ! sudo -u "$SUDO_USER" grep -q "starship init" "$BASHRC_PATH"; then
  sudo -u "$SUDO_USER" cat << 'EOF' >> "$BASHRC_PATH"

# Initialize Starship prompt
eval "$(starship init bash)"
EOF
  print_success "✅ Added Starship prompt initialization to $BASHRC_PATH"
else
  print_info "ℹ️ Starship prompt initialization already present, skipping."
fi

# --- fastfetch on login ---
if ! sudo -u "$SUDO_USER" grep -q "^fastfetch$" "$BASHRC_PATH"; then
  sudo -u "$SUDO_USER" echo -e "\n# Run fastfetch on terminal start\nfastfetch" >> "$BASHRC_PATH"
  print_success "✅ Added fastfetch command to $BASHRC_PATH"
else
  print_info "ℹ️ fastfetch command already present, skipping."
fi

# --- Copy Catppuccin config files ---
# Using the new CONFIGS_DIR for consistency
if [ -d "$CONFIGS_DIR" ]; then
  print_info "Copying Catppuccin config files from $CONFIGS_DIR to /home/$SUDO_USER/.config/"

  run_command "mkdir -p /home/$SUDO_USER/.config/starship" "Create Starship config dir" "no" "no"
  run_command "mkdir -p /home/$SUDO_USER/.config/fastfetch" "Create Fastfetch config dir" "no" "no"

  # Copying individual configs for clarity and to avoid issues with hidden files
  run_command "cp -rv \"$CONFIGS_DIR/starship.toml\" /home/$SUDO_USER/.config/starship/" "Copy Starship config" "yes" "no"
  run_command "cp -rv \"$CONFIGS_DIR/fastfetch/config.jsonc\" /home/$SUDO_USER/.config/fastfetch/" "Copy Fastfetch config" "yes" "no"
  # Note: The original script copied "$REPO_DIR/configs/*" to ~/.config/. This is too broad and risky.
  # I'm assuming you primarily meant starship.toml and fastfetch/config.jsonc,
  # as these are directly mentioned in the Catppuccin context.
  # If there are other configs in the top-level 'configs' directory that need copying,
  # you'll need to specify them.

  print_success "✅ Catppuccin theme config files copied (Starship, Fastfetch)."
else
  print_warning "⚠️ Configs directory $CONFIGS_DIR not found. Skipping config copy."
fi

print_info "👉 Please reload your shell or run: source $BASHRC_PATH"
log_message "Prerequisites setup completed."
