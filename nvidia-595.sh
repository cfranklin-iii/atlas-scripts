#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NVIDIA_VERSION="595.80"
NVIDIA_RUN_FILE="NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run"
NVIDIA_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/${NVIDIA_RUN_FILE}"

if command -v nvidia-smi &> /dev/null; then
    echo -e "${GREEN}NVIDIA drivers are already installed.${NC}"
    echo -e -n "${GREEN}Do you want to ${YELLOW}reinstall the drivers, install the NVIDIA Container Toolkit or ${RED}exit?${NC} (1/2/3): " && read answer
    if [[ $answer == "1" ]]; then
        echo -e "${YELLOW}Reinstalling NVIDIA drivers (v${NVIDIA_VERSION})...${NC}"
        wget $NVIDIA_URL
        chmod +x $NVIDIA_RUN_FILE
        sudo apt update &>/dev/null
        sudo apt install -y build-essential dkms &>/dev/null
        echo -e "${YELLOW}Verifying package installation...${NC}"
        which make
        make --version
        gcc --version
        echo -e "${YELLOW}Running NVIDIA driver installation...${NC}"
        sudo ./${NVIDIA_RUN_FILE}
    elif [[ $answer == "2" ]]; then
        echo -e "${YELLOW}Installing NVIDIA Container Toolkit...${NC}"
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        sudo gpg --dearmor -yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        sudo apt-get update
        sudo apt-get install -y nvidia-container-toolkit
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
    else
        echo -e "${RED}Exiting.${NC}"
        exit 0
    fi
else
    echo -e -n "${YELLOW}NVIDIA drivers not found. Install drivers v${NVIDIA_VERSION} (1) or exit (2)? ${NC} " && read answer2
    if [[ $answer2 == "1" ]]; then
        echo -e "${YELLOW}Installing drivers...${NC}"
        wget $NVIDIA_URL
        chmod +x $NVIDIA_RUN_FILE
        echo -e "${YELLOW}Updating package list...${NC}"
        sudo apt update
        echo -e "${YELLOW}Installing essential packages...${NC}"
        sudo apt install -y build-essential dkms
        echo -e "${YELLOW}Running NVIDIA driver installation...${NC}"
        sudo ./${NVIDIA_RUN_FILE}
    else
        exit 0
    fi
fi
