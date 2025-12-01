#!/usr/bin/env bash

# Container image pulling
# Sourced by bootstrap.sh

setup_containers() {
  local repo_dir="$INSTALL_DIR/norsk-studio-docker"

  echo "Pulling Norsk container images..."
  cd "$repo_dir"
  ./deployed/norsk-containers.sh pull --quiet

  echo "Pulling support container images..."
  ./deployed/support-containers.sh pull --quiet

  echo "Pulling htpasswd utility image..."
  docker pull xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c
}
