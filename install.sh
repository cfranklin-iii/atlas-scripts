#!/usr/bin/env bash
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

PACKAGES=(git fish tree btop fastfetch curl wget)

info "Detecting package manager..."
detect_pkg_manager

case "$PKG_MANAGER" in
    apt)
        UPDATE=(sudo apt update); UPGRADE=(sudo apt full-upgrade -y)
        INSTALL=(sudo apt install -y); PACKAGES+=(build-essential) ;;
    pacman)
        UPDATE=(sudo pacman -Syu --noconfirm); UPGRADE=(true)
        INSTALL=(sudo pacman -S --needed --noconfirm); PACKAGES+=(base-devel) ;;
esac

info "Updating system packages using $PKG_MANAGER..."
if "${UPDATE[@]}" && "${UPGRADE[@]}"; then
    ok "System packages updated successfully!"
else
    err "Failed to update system packages. Check your network and package manager."
    exit 1
fi

info "\nInstalling software..."
if output=$("${INSTALL[@]}" "${PACKAGES[@]}" 2>&1); then
    ok "Successfully installed: ${PACKAGES[*]}!"
else
    err "Failed to install packages.\nDetails: $output"
    exit 1
fi

ok "\nInstallation complete!"
