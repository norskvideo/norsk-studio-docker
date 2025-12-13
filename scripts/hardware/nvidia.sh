#!/usr/bin/env bash

# NVIDIA GPU hardware profile
# Installs driver 575-server + container toolkit for Ubuntu 24.04
# Sourced by bootstrap.sh

setup_hardware() {
  echo "Setting up NVIDIA GPU support..."

  cd "$INSTALL_DIR"

  # 1. Verify GPU present
  if ! lspci | grep -qi nvidia; then
    echo "ERROR: No NVIDIA GPU detected via lspci" >&2
    exit 1
  fi

  # 2. Install prerequisites
  echo "Installing kernel headers and build tools..."
  DEBIAN_FRONTEND=noninteractive \
    apt-get update
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -q \
      linux-headers-$(uname -r) \
      build-essential \
      pciutils

  # 3. Check driver availability
  echo "Checking for nvidia-driver-575-server availability..."
  if ! apt-cache policy nvidia-driver-575-server | grep -q 'Candidate:'; then
    echo "ERROR: nvidia-driver-575-server not available in Ubuntu repositories" >&2
    echo "Available NVIDIA server drivers:" >&2
    apt-cache search nvidia-driver | grep server >&2
    exit 1
  fi

  # 4. Install NVIDIA driver 575-server
  echo "Installing NVIDIA driver 575-server..."
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -q \
      nvidia-driver-575-server \
      nvidia-utils-575-server

  # 5. Add NVIDIA container toolkit repo
  echo "Adding NVIDIA container toolkit repository..."
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  # 6. Install nvidia-container-toolkit
  echo "Installing nvidia-container-toolkit..."
  DEBIAN_FRONTEND=noninteractive \
    apt-get update
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -q nvidia-container-toolkit

  # 7. Configure Docker runtime
  echo "Configuring Docker for NVIDIA runtime..."
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker

  # 8. Export hardware config
  echo 'export DEPLOY_HARDWARE="nvidia"' >> "$REPO_DIR/deployed/${PLATFORM^}/norsk-config.sh"

  echo "NVIDIA setup complete - reboot required for driver to load"
}
