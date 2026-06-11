#!/usr/bin/env bash

# === Stop on any errors ===
set -e

# === Set variables ===
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_DIR/dotfiles"

# -- Colors --
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'


echo "Pulling fish configs from $REPO_DIR..."

# Fish Setup
# Should check if fish is installed, if not send an error message
if command -v fish &> /dev/null; then
    echo -e "\n${YELLOW}Setting up fish shell...${NC}"
    fish_config="$HOME/.config/fish/conf.d"
    mkdir -p "$fish_config"

    cp -r "$DOTFILES_DIR/fish/config.fish" "$HOME/.config/fish/config.fish"
    cp -r "$DOTFILES_DIR/fish/aliases.fish" "$fish_config/aliases.fish"
    mkdir -p "$HOME/.config/fish/functions"
    cp -r "$DOTFILES_DIR/fish/functions/"* "$HOME/.config/fish/functions/"
    echo -e "${GREEN} Fish config and functions loaded, aliases copied to: $fish_config/aliases.fish${NC}"
else
    echo -e "${RED} ERROR: Fish shell not installed, skipping.${NC}"
fi
