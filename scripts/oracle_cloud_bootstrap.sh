#!/usr/bin/env bash

# Bootstrap script for Norsk Studio on Oracle Cloud
# Tested with Ubuntu 22.04 LTS
#
# requirements:
# - run as root
# - set the NORSK_LICENSE environment variable to contain the license json
# - set the STUDIO_PASSWORD environment variable

set -euxo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Install git and clone repo
apt-get update
apt-get install -y git

mkdir -p /var/norsk-studio
cd /var/norsk-studio
git clone -b git-mgt https://github.com/norskvideo/norsk-studio-docker.git

cd /var/norsk-studio/norsk-studio-docker

# Run bootstrap script
./scripts/bootstrap.sh \
  --hardware=none \
  --platform=oracle \
  --license="$NORSK_LICENSE" \
  --password="$STUDIO_PASSWORD" \
  --domain="${DOMAIN_NAME:-}" \
  --certbot-email="${CERTBOT_EMAIL:-}"
