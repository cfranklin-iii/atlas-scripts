#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if command -v nvidia-smi &> /dev/null; then
    echo "NVIDIA drivers are already installed."
    read -p "Do you want to ${YELLOW}reinstall the drivers, install the NVIDIA Container Toolkit or ${RED}exit?${NC} (1/2/3): " answer
    if [[ $answer == "1" ]]; then
        echo "Reinstalling NVIDIA drivers..."
        # Pull the drivers from nvidia.com
        wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.80/NVIDIA-Linux-x86_64-595.80.run
        # Make it executable
        chmod +x NVIDIA-Linux-x86_64-595.80.run
        # Make sure essential packages are installed
        sudo apt update &>/dev/null
        sudo apt install -y build-essential dkms &>/dev/null
        # Verify package installation
        echo "Verifying package installation..."
        which make
        make --version
        gcc --version
        # Run the driver installation
        echo "Running NVIDIA driver installation..."
        ./NVIDIA-Linux-x86_64-595.80.run
    elif [[ $answer == "2" ]]; then
        echo "Installing NVIDIA Container Toolkit..."
        # For Debian (Trixie) Containers/Docker
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        apt install -y nvidia-container-toolkit
        nvidia-ctk runtime configure --runtime=docker
        systemctl restart docker
    else
        echo "Exiting."
        exit 0
    fi
else
    # Logic for when nvidia-smi is not found
    read -p "NVIDIA drivers not found. Install drivers (1) or exit (2)? " answer2
    if [[ $answer2 == "1" ]]; then
        echo "Installing drivers..."
        wget https://us.download.nvidia.com/XFree86/Linux-x86_64/595.80/NVIDIA-Linux-x86_64-595.80.run
        chmod +x NVIDIA-Linux-x86_64-595.80.run
        echo "Updating package list..."
        apt update
        echo "Installing essential packages..."
        apt install -y build-essential dkms
        echo "Running NVIDIA driver installation..."
        ./NVIDIA-Linux-x86_64-595.80.run
    else
        exit 0
    fi
fi



# For Debian (Trixie) Containers/Docker
#docker info | grep -A5 Runtimes
#docker run --rm --runtime=nvidia --gpus all \
#  nvidia/cuda:12.9.0-base-ubuntu24.04 nvidia-smi