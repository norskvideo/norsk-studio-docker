#!/usr/bin/env bash

# MOCK: Netint Quadra hardware profile
# For testing without actual hardware

setup_hardware() {
  echo "[MOCK] Setting up Netint Quadra support..."
  echo "[MOCK] Would download: Quadra_V5.2.0.zip, yasm-1.3.0.tar.gz"
  echo "[MOCK] Would verify checksums"
  echo "[MOCK] Would install build dependencies"
  echo "[MOCK] Would build yasm"
  echo "[MOCK] Would build libxcoder"
  echo "[MOCK] Would add norsk user to disk group"
  echo "[MOCK] Would enable nilibxcoder.service"
  echo "[MOCK] Quadra setup complete (mocked)"
}
