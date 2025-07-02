#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source helper file
source $SCRIPT_DIR/helper.sh

trap 'trap_message' INT TERM

log_message "Installation started"
print_bold_blue "\nSimple Hyprland"
echo "---------------"

check_root
check_os

run_script "prerequisites.sh" "Prerequisites Setup"
run_script "gpu.sh" "GPU Driver Installation"
run_script "hypr.sh" "Hyprland & Critical Software Setup"
run_script "utilities.sh" "Basic Utilities & Configs Setup"
run_script "theming.sh" "Themes and Tools Setup"
run_script "final.sh" "Final Setup"

print_bold_blue "\n🌟 Setup Complete\n"
log_message "Installation completed successfully"
