#!/usr/bin/env bash
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh" || {
    echo "atlas-scripts: cannot load lib/common.sh" >&2; exit 1
}

VERSION="595.99.02"
RUN_FILE="NVIDIA-Linux-x86_64-${VERSION}.run"
BASE_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${VERSION}"
URL="$BASE_URL/$RUN_FILE"
SUM_URL="$URL.sha256sum"

# Download into a temp dir (auto-cleaned on exit) so we never pollute the cwd.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
RUN_PATH="$WORK_DIR/$RUN_FILE"

# Conditions that make the runfile installer fail halfway through. Better to
# say so up front than to leave the machine with a half-installed driver.
preflight() {
    if pgrep -x Xorg &>/dev/null || pgrep -x X &>/dev/null || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        err "A graphical session appears to be running."
        info "The installer cannot replace a driver that is in use. Switch to a TTY"
        info "(Ctrl+Alt+F3) and stop the display manager first:"
        info "  sudo systemctl stop display-manager"
        confirm "Continue anyway?" || exit 1
    fi

    if command -v mokutil &>/dev/null && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
        err "Secure Boot is enabled."
        info "The runfile builds an unsigned kernel module, which the kernel will refuse"
        info "to load. Disable Secure Boot in firmware, or enroll a MOK, first."
        confirm "Continue anyway?" || exit 1
    fi

    if lsmod 2>/dev/null | grep -q '^nouveau'; then
        info "Note: nouveau is loaded and conflicts with the NVIDIA driver."
        info "The installer will offer to blacklist it; a reboot is needed afterwards."
    fi
}

verify_download() {
    info "Verifying checksum..."
    if wget -q -O "$RUN_PATH.sha256sum" "$SUM_URL"; then
        (cd "$WORK_DIR" && sha256sum -c "$RUN_FILE.sha256sum") \
            || die "Checksum mismatch. Refusing to run the installer."
        ok "Checksum verified."
    else
        err "Could not fetch $SUM_URL, so the download is unverified."
        confirm "Run the unverified installer as root anyway?" || exit 1
    fi
}

install_driver() {
    preflight

    info "Downloading NVIDIA driver (v${VERSION})..."
    wget -O "$RUN_PATH" "$URL" || die "Failed to download from $URL"
    verify_download
    chmod +x "$RUN_PATH"

    info "Installing build essentials (build tools + dkms)..."
    detect_pkg_manager || exit 1
    case "$PKG_MANAGER" in
        apt)    sudo apt-get update && sudo apt-get install -y build-essential dkms ;;
        pacman) sudo pacman -Syu --noconfirm base-devel dkms ;;
        dnf)    sudo dnf install -y @development-tools dkms kernel-devel ;;
        zypper) sudo zypper --non-interactive install gcc make dkms kernel-default-devel ;;
    esac

    info "Verifying build tools..."
    make --version && gcc --version

    # --dkms registers the module so it is rebuilt on kernel updates. Without
    # it the driver stops loading the next time the kernel is bumped.
    info "Running NVIDIA driver installation..."
    sudo "$RUN_PATH" --dkms

    ok "Driver installation finished. A reboot is required to load it."
    if confirm "Reboot now?"; then
        sudo reboot
    fi
}

install_toolkit() {
    info "Installing NVIDIA Container Toolkit..."
    if ! command -v apt-get &>/dev/null; then
        err "Container Toolkit auto-install is only supported on apt-based systems."
        info "On Arch, install 'nvidia-container-toolkit' from the AUR, then run:"
        info "  sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
        exit 1
    fi
    command -v docker &>/dev/null \
        || die "Docker is not installed. Install Docker before the Container Toolkit."

    # -f so an HTTP error is not silently written out as a bogus keyring or
    # apt source; pipefail (set in common.sh) surfaces failures mid-pipeline.
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
        | sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        || die "Failed to fetch the NVIDIA GPG key."
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
        | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
        | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null \
        || die "Failed to write the Container Toolkit apt source."

    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    ok "Container Toolkit installed and wired into Docker."
}

if command -v nvidia-smi &>/dev/null; then
    ok "NVIDIA drivers are already installed."
    read -rp "Reinstall drivers (1), install Container Toolkit (2), or exit (3)? " answer
    case "$answer" in
        1) install_driver ;;
        2) install_toolkit ;;
        *) info "Exiting."; exit 0 ;;
    esac
else
    read -rp "NVIDIA drivers not found. Install drivers v${VERSION} (1) or exit (2)? " answer
    case "$answer" in
        1) install_driver ;;
        *) exit 0 ;;
    esac
fi
