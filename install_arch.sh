#!/usr/bin/env bash

# === Stop on any errors ===
set -e

# -- Colors --
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Updating system packages...${NC}"
# Note: This uses 'apt', assuming a Debian/Ubuntu-based distribution.
# If you are on Arch Linux, change this to 'sudo pacman -Syu'
sudo pacman -Syu --noconfirm

echo -e "\n${YELLOW}Installing software...${NC}"
# Add or remove packages in this list as needed
packages=(
    git
    fish
    tree
    btop
    fastfetch
    curl
    wget
)

for pkg in "${packages[@]}"; do
    if output=$(sudo pacman -S --noconfirm "$pkg" 2>&1); then
        echo -e "${GREEN}Successfully installed $pkg!${NC}"
    else
        echo -e "${RED}Failed to install $pkg.${NC}"
        echo -e "${RED}Details: $output${NC}"
    fi
done

echo -e "\n${GREEN}Installation complete!${NC}"