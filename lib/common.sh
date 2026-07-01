# shellcheck shell=bash
# Shared helpers for atlas-scripts. Source this file: . "$(dirname "$0")/lib/common.sh"

set -e

# -- Colors --
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# -- Logging helpers --
info() { echo -e "${YELLOW}$*${NC}"; }
ok()   { echo -e "${GREEN}$*${NC}"; }
err()  { echo -e "${RED}$*${NC}" >&2; }

# -- Package manager detection --
# Sets PKG_MANAGER (apt|pacman) or exits. Safe to call multiple times.
detect_pkg_manager() {
    if command -v apt &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v pacman &>/dev/null; then
        PKG_MANAGER="pacman"
    else
        err "Unsupported package manager. Please install packages manually."
        exit 1
    fi
}
