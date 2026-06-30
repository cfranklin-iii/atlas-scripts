#!/usr/bin/env bash

# === Stop on any errors ===
set -e

# -- Colors --
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Detecting package manager...${NC}"

COMMON_PACKAGES=(git fish tree btop fastfetch curl wget)

if command -v apt &> /dev/null; then
    PKG_MANAGER="apt"
    UPDATE_CMD=(sudo apt update)
    UPGRADE_CMD=(sudo apt full-upgrade -y)
    INSTALL_CMD=(sudo apt install -y)
    PACKAGES=("${COMMON_PACKAGES[@]}" build-essential)
elif command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
    UPDATE_CMD=(sudo pacman -Syu --noconfirm)
    UPGRADE_CMD=(true)
    INSTALL_CMD=(sudo pacman -S --needed --noconfirm)
    PACKAGES=("${COMMON_PACKAGES[@]}" base-devel)
else
    echo -e "${RED}Unsupported package manager. Please install packages manually.${NC}"
    exit 1
fi

echo -e "${YELLOW}Updating system packages using $PKG_MANAGER...${NC}"
if "${UPDATE_CMD[@]}" && "${UPGRADE_CMD[@]}"; then
    echo -e "${GREEN}System packages updated successfully!${NC}"
else
    echo -e "${RED}Failed to update system packages. Please check your network connection and package manager settings.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Installing software...${NC}"
if output=$("${INSTALL_CMD[@]}" "${PACKAGES[@]}" 2>&1); then
    echo -e "${GREEN}Successfully installed: ${PACKAGES[*]}!${NC}"
else
    echo -e "${RED}Failed to install packages.${NC}"
    echo -e "${RED}Details: $output${NC}"
    exit 1
fi

echo -e "\n${GREEN}Installation complete!${NC}"
