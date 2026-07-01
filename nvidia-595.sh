#!/usr/bin/env bash
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

VERSION="595.80"
RUN_FILE="NVIDIA-Linux-x86_64-${VERSION}.run"
URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${VERSION}/${RUN_FILE}"

# Download into a temp dir (auto-cleaned on exit) so we never pollute the cwd.
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
RUN_PATH="$WORK_DIR/$RUN_FILE"

install_driver() {
    info "Downloading NVIDIA driver (v${VERSION})..."
    wget -O "$RUN_PATH" "$URL" || { err "Failed to download from $URL"; exit 1; }
    chmod +x "$RUN_PATH"

    info "Installing build essentials (build tools + dkms)..."
    detect_pkg_manager
    case "$PKG_MANAGER" in
        apt)    sudo apt update && sudo apt install -y build-essential dkms ;;
        pacman) sudo pacman -Syu --noconfirm base-devel dkms ;;
    esac

    info "Verifying build tools..."
    make --version && gcc --version

    info "Running NVIDIA driver installation..."
    sudo "$RUN_PATH"
}

install_toolkit() {
    info "Installing NVIDIA Container Toolkit..."
    if ! command -v apt &>/dev/null; then
        err "Container Toolkit auto-install is only supported on apt-based systems."
        info "On Arch, install 'nvidia-container-toolkit' from the AUR, then run:"
        info "  sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker"
        exit 1
    fi
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
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
