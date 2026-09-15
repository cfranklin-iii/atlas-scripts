#!/usr/bin/env bash
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh" || {
    echo "atlas-scripts: cannot load lib/common.sh" >&2; exit 1
}

PACKAGES=(git fish tree btop fastfetch curl wget)

info "Detecting package manager..."
detect_pkg_manager || exit 1

case "$PKG_MANAGER" in
    apt)
        UPDATE=(sudo apt-get update); UPGRADE=(sudo apt-get full-upgrade -y)
        INSTALL=(sudo apt-get install -y); PACKAGES+=(build-essential) ;;
    pacman)
        UPDATE=(sudo pacman -Syu --noconfirm); UPGRADE=(true)
        INSTALL=(sudo pacman -S --needed --noconfirm); PACKAGES+=(base-devel) ;;
    dnf)
        UPDATE=(sudo dnf -y upgrade --refresh); UPGRADE=(true)
        INSTALL=(sudo dnf install -y); PACKAGES+=(@development-tools) ;;
    zypper)
        UPDATE=(sudo zypper --non-interactive refresh); UPGRADE=(sudo zypper --non-interactive update)
        INSTALL=(sudo zypper --non-interactive install); PACKAGES+=(gcc make) ;;
esac

info "Updating system packages using $PKG_MANAGER..."
if "${UPDATE[@]}" && "${UPGRADE[@]}"; then
    ok "System packages updated successfully!"
else
    die "Failed to update system packages. Check your network and package manager."
fi

# Output is streamed rather than captured: a full upgrade takes minutes, and a
# captured sudo password prompt looks like a hang.
info "\nInstalling software..."
if "${INSTALL[@]}" "${PACKAGES[@]}"; then
    ok "Successfully installed: ${PACKAGES[*]}!"
else
    # One unavailable package (fastfetch is missing from older apt repos) fails
    # the whole batch, so retry individually and install everything that exists.
    err "Batch install failed. Retrying one package at a time..."
    FAILED=()
    for pkg in "${PACKAGES[@]}"; do
        "${INSTALL[@]}" "$pkg" || FAILED+=("$pkg")
    done
    if [ ${#FAILED[@]} -gt 0 ]; then
        err "\nCould not install: ${FAILED[*]}"
        info "These are probably not in your distro's repos; install them manually."
        exit 1
    fi
    ok "Successfully installed: ${PACKAGES[*]}!"
fi

ok "\nInstallation complete!"
