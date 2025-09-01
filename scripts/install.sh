#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_HOME="/home/${SUDO_USER:-$USER}"
export SUDO_USER  # needed for helper functions

source "$SCRIPT_DIR/helper.sh"

check_root
check_os

print_bold_blue "\n🚀 Starting Full Hyprland Setup"
echo "-------------------------------------"

# Run each phase script that exists and is executable
for phase in prerequisites utilities gpu; do
  PHASE_SCRIPT="$SCRIPT_DIR/$phase.sh"
  if [[ -x "$PHASE_SCRIPT" ]]; then
    print_header "Executing $phase.sh"
    bash "$PHASE_SCRIPT"
  else
    print_warning "Phase script '$phase.sh' not found or not executable. Skipping."
  fi
done

print_bold_blue "\n✅ Setup Complete! You can now reboot to apply changes."
