#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/helper.sh"

print_info "\nDetecting GPU..."

GPU_INFO=$(lspci | grep -Ei "VGA|3D")

if echo "$GPU_INFO" | grep -qi "nvidia"; then
    print_bold_blue "\nNVIDIA GPU detected."
    run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers" "yes"
elif echo "$GPU_INFO" | grep -qi "amd"; then
    print_bold_blue "\nAMD GPU detected."
    run_command "pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon libva-mesa-driver mesa-vdpau" "Install AMD drivers" "yes"
elif echo "$GPU_INFO" | grep -qi "intel"; then
    print_bold_blue "\nIntel GPU detected."
    run_command "pacman -S --noconfirm mesa libva-intel-driver intel-media-driver vulkan-intel" "Install Intel drivers" "yes"
else
    print_warning "\nNo supported GPU detected. Info: $GPU_INFO"
    if ask_confirmation "Try installing NVIDIA drivers anyway?"; then
        run_command "pacman -S --noconfirm nvidia nvidia-utils nvidia-settings" "Install NVIDIA drivers (forced)" "yes"
    fi
fi
