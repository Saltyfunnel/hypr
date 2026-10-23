#!/bin/bash
################################################################################
# Hyprland Installer - 2026 Edition
# Unified installer for AMD/Nvidia/Intel GPUs with automatic configuration
################################################################################

set -Eeuo pipefail

################################################################################
# COLORS & STYLES
################################################################################

RST="\e[0m"
RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"
WHT="\e[37m"
BBLK="\e[90m"; BRED="\e[91m"; BGRN="\e[92m"; BYLW="\e[93m"
BBLU="\e[94m"; BCYN="\e[96m"; BWHT="\e[97m"
BLD="\e[1m"; DIM="\e[2m"

STEP=0
TOTAL_STEPS=13

LOG_DIR="/tmp/hypr-install-logs"
mkdir -p "$LOG_DIR"

################################################################################
# HELPER FUNCTIONS
################################################################################

_cols() { tput cols 2>/dev/null || echo 80; }

# repeat <char> <count>  (safe when count is 0 or negative)
repeat() {
    local ch="$1" n="$2" out=""
    local i
    for (( i = 0; i < n; i++ )); do out+="$ch"; done
    printf '%s' "$out"
}

hr() {
    local cols; cols=$(_cols)
    echo -e "${BBLK}$(repeat '─' "$cols")${RST}"
}
