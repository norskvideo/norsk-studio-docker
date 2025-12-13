#!/usr/bin/env bash

# Common setup: Docker, user, dependencies, repo clone
# Sourced by bootstrap.sh

setup_common() {
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
  rm /tmp/get-docker.sh

  echo "Creating norsk user and group..."
  if ! getent group norsk >/dev/null; then
    groupadd norsk
  fi
  if ! id norsk >/dev/null 2>&1; then
    useradd -g norsk -G root,docker -ms /bin/bash norsk
  else
    # User exists, ensure in correct groups
    usermod -aG root,docker norsk
  fi

  echo "Creating logs directory..."
  mkdir -p /var/log/norsk/{norsk-media,norsk-studio,nginx-proxy,oauth2-proxy,certbot-dns}
  chown -R norsk:norsk /var/log/norsk

  echo "Installing system dependencies..."
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q certbot dnsutils git

  echo "Configuring network tuning for media streaming..."
  cat > /etc/sysctl.d/99-norsk-network.conf <<'EOF'
# Network tuning for Norsk media streaming
# Optimized for high-bitrate UDP video streams

# Buffer sizes (bytes)
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.core.rmem_default=262144
net.core.wmem_default=262144

# Network device
net.core.netdev_max_backlog=30000

# UDP-specific
net.ipv4.udp_rmem_min=16384
net.ipv4.udp_wmem_min=16384

# TCP (for control/signaling)
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.ipv4.tcp_mem=786432 1048576 1572864
net.ipv4.tcp_window_scaling=1
EOF
  sysctl -p /etc/sysctl.d/99-norsk-network.conf

  echo "Cloning repository..."
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "Repository already exists, pulling latest..."
    cd "$INSTALL_DIR"
    git fetch origin
    git checkout "$REPO_BRANCH"
    git pull origin "$REPO_BRANCH"
  else
    git clone -b "$REPO_BRANCH" "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
  fi

  echo "Setting ownership..."
  chown -R norsk:norsk "$INSTALL_DIR"

  # Download example media files
  if [[ "${DOWNLOAD_MEDIA:-true}" == "true" ]]; then
    echo "Downloading example media files..."
    local media_dir="$REPO_DIR/data/media"
    mkdir -p "$media_dir"
    for source in action.mp4 wildlife.ts; do
      if curl --fail -L "https://s3.eu-west-1.amazonaws.com/norsk.video/media-examples/data/$source" -o "$media_dir/$source"; then
        echo "Downloaded: $source"
      else
        echo "Warning: Failed to download $source (continuing anyway)"
      fi
    done
    chown -R norsk:norsk "$media_dir"
  else
    echo "Skipping media download (disabled)"
  fi
}
