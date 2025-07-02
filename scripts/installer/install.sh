#!/bin/bash

# Define script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define original user
SUDO_USER=$(logname)

# Export these for scripts that use them
export SCRIPT_DIR
export SUDO_USER

# Trap Ctrl+C or kill
trap 'echo -e "\n❌ Script interrupted. Exiting..."; exit 1' INT TERM

# Source helper if needed (only for print_* functions)
source "$SCRIPT_DIR/helper.sh"

print_bold_blue "\n🚀 Starting Simple Hyprland Setup"
echo "-------------------------------------"

# Basic checks
if [[ "$EUID" -ne 0 ]]; then
    echo -e "\n❌ Please run this script as root (e.g. with sudo)"
    exit 1
fi

# Optional: check OS
source /etc/os-release
if [[ "$ID" != "arch" ]]; then
    echo -e "\n⚠️  This script is meant for Arch Linux. Your OS: $PRETTY_NAME"
    read -p "Continue anyway? (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 1
fi

# Run each section
bash "$SCRIPT_DIR/prerequisites.sh"
bash "$SCRIPT_DIR/gpu.sh"
bash "$SCRIPT_DIR/hypr.sh"
bash "$SCRIPT_DIR/utilities.sh"
bash "$SCRIPT_DIR/theming.sh"
bash "$SCRIPT_DIR/final.sh"

print_bold_blue "\n✅ Setup Complete!"
