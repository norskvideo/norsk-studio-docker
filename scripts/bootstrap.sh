#!/usr/bin/env bash

# Unattended bootstrap script for Norsk Studio
# Designed for cloud-init / stackscripts

set -euo pipefail

# Defaults
HARDWARE="auto"
PLATFORM=""
INSTALL_DIR="/var/norsk-studio"
REPO_URL="https://github.com/norskvideo/norsk-studio-docker.git"
REPO_BRANCH="git-mgt"
NORSK_LICENSE=""
STUDIO_PASSWORD=""
DOMAIN_NAME=""
CERTBOT_EMAIL=""

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Unattended installation of Norsk Studio for cloud deployments.

OPTIONS:
  --hardware=TYPE       Hardware profile: auto|none|quadra|nvidia (default: auto)
  --platform=NAME       Platform: linode|google|oracle|local (auto-detected if omitted)
  --install-dir=PATH    Install directory (default: /var/norsk-studio)
  --repo-branch=BRANCH  Git branch to clone (default: git-mgt)
  --license=JSON        Norsk license JSON string (required)
  --password=PASS       Studio admin password (required)
  --domain=NAME         Optional domain name for deployment
  --certbot-email=EMAIL Optional email for certbot renewal notices
  --help                Show this help

EXAMPLES:
  # Basic software-only install on Linode
  $0 --license="\$LICENSE_JSON" --password="secret123"

  # Quadra hardware on Linode with domain
  $0 --hardware=quadra --license="\$LICENSE_JSON" --password="secret123" \\
     --domain=studio.example.com --certbot-email=admin@example.com

EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --hardware=*)
      HARDWARE="${1#*=}"
      shift
      ;;
    --platform=*)
      PLATFORM="${1#*=}"
      shift
      ;;
    --install-dir=*)
      INSTALL_DIR="${1#*=}"
      shift
      ;;
    --repo-branch=*)
      REPO_BRANCH="${1#*=}"
      shift
      ;;
    --license=*)
      NORSK_LICENSE="${1#*=}"
      shift
      ;;
    --password=*)
      STUDIO_PASSWORD="${1#*=}"
      shift
      ;;
    --domain=*)
      DOMAIN_NAME="${1#*=}"
      shift
      ;;
    --certbot-email=*)
      CERTBOT_EMAIL="${1#*=}"
      shift
      ;;
    --help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

# Validation
if [[ -z "$NORSK_LICENSE" ]]; then
  echo "Error: --license is required" >&2
  exit 1
fi

if [[ -z "$STUDIO_PASSWORD" ]]; then
  echo "Error: --password is required" >&2
  exit 1
fi

if [[ ! "$HARDWARE" =~ ^(auto|none|quadra|nvidia)$ ]]; then
  echo "Error: --hardware must be one of: auto, none, quadra, nvidia" >&2
  exit 1
fi

# Auto-detect hardware if requested
if [[ "$HARDWARE" == "auto" ]]; then
  echo "Auto-detecting hardware..."
  if command -v lspci >/dev/null 2>&1 && lspci | grep -iq netint; then
    HARDWARE="quadra"
    echo "Detected: Netint Quadra"
  else
    HARDWARE="none"
    echo "Detected: No hardware acceleration"
  fi
fi

# Export for use by modules
export HARDWARE
export PLATFORM
export INSTALL_DIR
export REPO_URL
export REPO_BRANCH
export NORSK_LICENSE
export STUDIO_PASSWORD
export DOMAIN_NAME
export CERTBOT_EMAIL

echo "=== Norsk Studio Bootstrap ==="
echo "Hardware: $HARDWARE"
echo "Platform: ${PLATFORM:-auto-detect}"
echo "Install dir: $INSTALL_DIR"
echo "Branch: $REPO_BRANCH"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root" >&2
  exit 1
fi

# Source lib modules (order matters)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

for module in 00-common.sh 10-secrets.sh 20-platform.sh 30-containers.sh; do
  if [[ ! -f "$LIB_DIR/$module" ]]; then
    echo "Error: Missing required module: $LIB_DIR/$module" >&2
    exit 1
  fi
  source "$LIB_DIR/$module"
done

# Execute installation phases
echo "=== Phase 1: Common setup ==="
setup_common

echo ""
echo "=== Phase 2: Secrets ==="
setup_secrets

echo ""
echo "=== Phase 3: Platform configuration ==="
setup_platform

echo ""
echo "=== Phase 4: Hardware profile ==="
if [[ -f "$SCRIPT_DIR/hardware/$HARDWARE.sh" ]]; then
  source "$SCRIPT_DIR/hardware/$HARDWARE.sh"
  setup_hardware
else
  echo "Error: Hardware profile not found: $HARDWARE" >&2
  exit 1
fi

echo ""
echo "=== Phase 5: Container images ==="
setup_containers

echo ""
echo "=== Phase 6: Systemd services ==="
echo "Enabling and starting systemd services..."
systemctl enable --now "$INSTALL_DIR/norsk-studio-docker/deployed/systemd/"*.service

echo ""
echo "=== Bootstrap complete ==="
echo "Norsk Studio will be available after services start"
if [[ -n "$DOMAIN_NAME" ]]; then
  echo "URL: https://$DOMAIN_NAME"
elif [[ -n "${DEPLOY_PUBLIC_IP:-}" ]]; then
  echo "URL: http://$DEPLOY_PUBLIC_IP"
fi
