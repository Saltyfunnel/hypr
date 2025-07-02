#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color


function print_error {
    echo -e "${RED}$1${NC}"
}

function print_success {
    echo -e "${GREEN}$1${NC}"
}

function print_warning {
    echo -e "${YELLOW}$1${NC}"
}

function print_info {
    echo -e "${BLUE}$1${NC}"
}

function print_bold_blue {
    echo -e "${BLUE}${BOLD}$1${NC}"
}

function print_header {
    echo -e "\n${BOLD}${BLUE}==> $1${NC}"
}

function ask_confirmation {
    while true; do
        read -p "$(print_warning "$1 (y/n): ")" -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_message "User confirmed: $1"
            return 0
        elif [[ $REPLY =~ ^[Nn]$ ]]; then
            log_message "User declined: $1"
            print_error "Operation cancelled."
            return 1
        else
            print_error "Invalid input. Please answer y or n."
        fi
    done
}

function run_command {
    local cmd="$1"
    local description="$2"
    local ask_confirm="${3:-yes}"
    local use_sudo="${4:-yes}"

    local full_cmd=""
    if [[ "$use_sudo" == "no" ]]; then
        full_cmd="sudo -u $SUDO_USER bash -c '$cmd'"
    else
        full_cmd="$cmd"
    fi

    log_message "Running: $description"
    print_info "\nCommand: $full_cmd"
    if [[ "$ask_confirm" == "yes" ]]; then
        if ! ask_confirmation "$description"; then
            log_message "$description skipped by user."
            return 1
        fi
    else
        print_info "$description"
    fi

    while ! eval "$full_cmd"; do
        print_error "Command failed: $cmd"
        log_message "Failed command: $cmd"
        if [[ "$ask_confirm" == "yes" ]]; then
            if ! ask_confirmation "Retry $description?"; then
                print_warning "$description not completed."
                log_message "$description not completed due to failure."
                return 1
            fi
        else
            print_warning "$description failed, no retry (auto mode)."
            log_message "$description failed, no retry."
            return 1
        fi
    done

    print_success "$description completed successfully."
    log_message "$description completed successfully."
    return 0
}

function check_root {
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root."
        log_message "Script not run as root. Exiting."
        exit 1
    fi

    SUDO_USER=$(logname)
    log_message "Running as root, original user: $SUDO_USER"
}

function check_os {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "arch" ]]; then
            print_warning "This script is designed for Arch Linux. Detected: $PRETTY_NAME"
            if ! ask_confirmation "Continue anyway?"; then
                log_message "Installation cancelled - unsupported OS."
                exit 1
            fi
        else
            print_success "Arch Linux detected. Proceeding."
            log_message "Arch Linux detected."
        fi
    else
        print_error "/etc/os-release not found. Cannot determine OS."
        if ! ask_confirmation "Continue anyway?"; then
            log_message "Installation cancelled - unknown OS."
            exit 1
        fi
    fi
}
