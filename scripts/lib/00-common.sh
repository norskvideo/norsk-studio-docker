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

  echo "Installing system dependencies..."
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -q certbot dnsutils git

  echo "Cloning repository..."
  mkdir -p "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  if [[ -d "$INSTALL_DIR/norsk-studio-docker" ]]; then
    echo "Repository already exists, pulling latest..."
    cd "$INSTALL_DIR/norsk-studio-docker"
    git fetch origin
    git checkout "$REPO_BRANCH"
    git pull origin "$REPO_BRANCH"
  else
    git clone -b "$REPO_BRANCH" "$REPO_URL"
    cd "$INSTALL_DIR/norsk-studio-docker"
  fi

  echo "Setting ownership..."
  chown -R norsk:norsk "$INSTALL_DIR"
}
