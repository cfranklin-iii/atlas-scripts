#!/usr/bin/env bash

# === Stop on any errors ===
set -e

# -- Colors --
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Updating system packages...${NC}"
# Note: This uses 'apt', assuming a Debian/Ubuntu-based distribution.
# If you are on Arch Linux, change this to 'sudo pacman -Syu'
sudo apt update && sudo apt full-upgrade -y

echo -e "\n${YELLOW}Installing software...${NC}"
# Add or remove packages in this list as needed
sudo apt install -y \
    git \
    fish \
    tree \
    btop \
    fastfetch \
    curl \
    wget \
    build-essential

echo -e "\n${GREEN}Installation complete!${NC}"
