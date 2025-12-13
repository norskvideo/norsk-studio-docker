#!/usr/bin/env bash

# Container image pulling
# Sourced by bootstrap.sh

setup_containers() {
  echo "Pulling container images (parallel)..."
  cd "$REPO_DIR"

  # Pull all images in parallel for faster bootstrap
  echo "  - Norsk containers..."
  ./deployed/norsk-containers.sh pull --quiet &
  local pid_norsk=$!

  echo "  - Support containers..."
  ./deployed/support-containers.sh pull --quiet &
  local pid_support=$!

  echo "  - htpasswd utility..."
  docker pull xmartlabs/htpasswd@sha256:fac862e543f80d72386492aa87b0f6f3c1c06a49a845e553ebea91750ce6320c &
  local pid_htpasswd=$!

  # Wait for all pulls to complete
  echo "  Waiting for all pulls to complete..."
  wait $pid_norsk $pid_support $pid_htpasswd

  echo "All container images pulled successfully"
}
