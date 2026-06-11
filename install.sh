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
if sudo apt update &>/dev/null && sudo apt full-upgrade -y &>/dev/null; then
    echo -e "${GREEN}System packages updated successfully!${NC}"
else
    echo -e "${RED}Failed to update system packages. Please check your network connection and package manager settings.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Installing software...${NC}"
# Add or remove packages in this list as needed
sudo apt install -y &>/dev/null \
    git \
    fish \
    tree \
    btop \
    fastfetch \
    curl \
    wget \
    build-essential

echo -e "${GREEN}Software installation complete!${NC}"
