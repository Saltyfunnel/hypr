#!/bin/bash
################################################################################
# Hyprland Installer - 2026 Edition
# Unified installer for AMD/Nvidia/Intel GPUs with automatic configuration
################################################################################

set -euo pipefail

################################################################################
# COLORS & STYLES
################################################################################

RST="\e[0m"
BLK="\e[30m"; RED="\e[31m"; GRN="\e[32m"; YLW="\e[33m"
BLU="\e[34m"; MAG="\e[35m"; CYN="\e[36m"; WHT="\e[37m"
BBLK="\e[90m"; BRED="\e[91m"; BGRN="\e[92m"; BYLW="\e[93m"
BBLU="\e[94m"; BMAG="\e[95m"; BCYN="\e[96m"; BWHT="\e[97m"
BLD="\e[1m"; DIM="\e[2m"; ITL="\e[3m"; UND="\e[4m"

STEP=0
TOTAL_STEPS=16
INSTALL_START=$(date +%s)

################################################################################
# HELPER FUNCTIONS
################################################################################

_cols() { tput cols 2>/dev/null || echo 80; }

hr() {
    local cols=$(_cols)
    echo -e "${BBLK}$(printf "%${cols}s" | tr ' ' "─")${RST}"
}

box_line() {
    local ch="$1" left="$2" right="$3"
    local cols=$(_cols)
    echo -e "${BBLK}${left}$(printf "%$((cols - 2))s" | tr ' ' "$ch")${right}${RST}"
}
