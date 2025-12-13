#!/usr/bin/env bash

# Netint Quadra hardware profile
# Sourced by bootstrap.sh

setup_hardware() {
  echo "Setting up Netint Quadra support..."

  cd "$INSTALL_DIR"

  # Download Quadra SDK and yasm
  echo "Downloading Quadra SDK and dependencies..."
  curl -O 'https://releases.netint.com/quadra/L8Q6OW2GRMBRJWF/Quadra_V5.2.0.zip'
  curl -O 'http://www.tortall.net/projects/yasm/releases/yasm-1.3.0.tar.gz'

  # Verify checksums
  if [[ \
    "$(md5sum Quadra_V5.2.0.zip | head -c 32)" == e458a75a9a09c8b59ce8a184ca9e5ad6 && \
    "$(md5sum yasm-1.3.0.tar.gz | head -c 32)" == fc9e586751ff789b34b1f21d572d96af \
  ]]; then
    echo "Checksums verified"
    python3 -c 'from zipfile import ZipFile; ZipFile("Quadra_V5.2.0.zip").extractall()'
    tar -zxf yasm-1.3.0.tar.gz
  else
    echo "Error: md5sums of Quadra_V5.2.0.zip or yasm-1.3.0.tar.gz did not match expected" >&2
    md5sum Quadra_V5.2.0.zip yasm-1.3.0.tar.gz
    exit 1
  fi

  # Install build dependencies
  echo "Installing Quadra build dependencies..."
  DEBIAN_FRONTEND=noninteractive \
    apt-get install -y -q \
        pkg-config git gcc ninja-build python3 \
        python3-pip flex bison libpng-dev zlib1g-dev gnutls-bin uuid-runtime \
        uuid-dev libglib2.0-dev libxml2 libxml2-dev

  pip3 install meson

  # Build yasm
  echo "Building yasm..."
  (cd yasm-1.3.0/; ./configure && make && make install)

  # Build libxcoder
  echo "Building libxcoder..."
  (cd Quadra_V5.2.0/Quadra_SW_V5.2.0_RC3/libxcoder; bash build.sh)

  # Give norsk user access to hardware
  echo "Configuring hardware access..."
  usermod -aG disk norsk

  # Configure Norsk with Quadra support
  echo 'export DEPLOY_HARDWARE="quadra"' >> "$REPO_DIR/deployed/${PLATFORM^}/norsk-config.sh"

  # Install systemd service for libxcoder initialization
  echo "Installing nilibxcoder systemd service..."
  systemctl enable --now "$REPO_DIR/deployed/Linode/nilibxcoder.service"

  echo "Quadra setup complete"
}
