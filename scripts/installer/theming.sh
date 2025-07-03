#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPT_DIR/helper.sh

log_message "Installation started for theming section"
print_info "\nStarting theming setup..."

# 1. GTK Theme Manager
run_command "pacman -S --noconfirm nwg-look" "Install nwg-look for GTK theme management" "yes"

# 2. Nautilus (GNOME Files)
run_command "pacman -S --noconfirm nautilus" "Install Nautilus file manager" "yes"

# 3. Qt Theme Engines
run_command "pacman -S --noconfirm qt5ct qt6ct kvantum" "Install Qt5/6 Settings and Kvantum theme engine" "yes"

# 4. Required fonts
run_command "pacman -S --noconfirm ttf-jetbrains-mono ttf-fira-code ttf-cascadia-code" "Install popular fonts" "yes"

# 5. Extract GTK + Icon themes
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes"
run_command "tar -xvf /home/$SUDO_USER/hypr/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"

# 6. Kvantum theme
run_command "yay -S --sudoloop --noconfirm kvantum-theme-catppuccin-git" "Install Catppuccin Kvantum theme" "yes" "no"

# 7. Kitty config
run_command "cp -r /home/$SUDO_USER/hypr/configs/kitty /home/$SUDO_USER/.config/" "Copy Kitty Catppuccin theme config" "yes" "no"

# 8. Catppuccin SDDM Theme
run_command "yay -S --sudoloop --noconfirm qt6-svg qt6-declarative qt5-quickcontrols2 qt5-graphicaleffects" "Install Qt dependencies for SDDM theming" "yes" "no"

run_command "git clone https://github.com/catppuccin/sddm.git /tmp/catppuccin-sddm" "Clone Catppuccin SDDM theme" "yes" "no"
run_command "cp -r /tmp/catppuccin-sddm/src /usr/share/sddm/themes/catppuccin-mocha" "Install Catppuccin SDDM theme" "yes"

run_command "chown -R root:root /usr/share/sddm/themes/catppuccin-mocha && chmod -R 755 /usr/share/sddm/themes/catppuccin-mocha" "Fix SDDM theme permissions" "yes"

# 9. Apply SDDM theme
if [ ! -f /etc/sddm.conf ]; then
    echo "[Theme]" | sudo tee /etc/sddm.conf
    echo "Current=catppuccin-mocha" | sudo tee -a /etc/sddm.conf
else
    sudo sed -i '/^\[Theme\]/,/^$/ s/^Current=.*/Current=catppuccin-mocha/' /etc/sddm.conf || echo -e "[Theme]\nCurrent=catppuccin-mocha" | sudo tee -a /etc/sddm.conf
fi

log_message "Catppuccin SDDM theme set in /etc/sddm.conf"

# Final instruction
print_info "\nPost-installation steps:"
print_bold_blue "🖌  Set your GTK and icon themes:"
echo "   - Run: nwg-look → choose GTK theme and icon set"
echo "   - Run: kvantummanager → apply Catppuccin"
echo "   - Run: qt6ct → set icon theme (e.g., Tela-circle-dracula)"
echo "   - Log out or restart SDDM to see the Catppuccin greeter"

print_success "\n✅ Theming completed successfully."

echo "------------------------------------------------------------------------"
