#!/bin/bash

# GCP Compute Engine startup script for Norsk Studio installation
# Tested with Ubuntu 24.04 LTS
#
# Prerequisites:
# 1. Service account with secretmanager.secretAccessor role
# 2. Secret Manager secrets created:
#    - norsk-license
#    - norsk-studio-password
# 3. Instance metadata:
#    - deploy_domain_name (optional)
#    - deploy_certbot_email (optional)
#    - hardware_profile (auto|none|nvidia)
#    - repo_branch

set -euxo pipefail

# Capture output
exec >/var/log/startup-script.log 2>&1

# Install gcloud CLI if not present (should be pre-installed on GCP instances)
if ! command -v gcloud &> /dev/null; then
  echo "Installing gcloud CLI..."
  curl https://sdk.cloud.google.com | bash
  exec -l $SHELL
fi

# Fetch secrets from Secret Manager
echo "Fetching secrets from Secret Manager..."
NORSK_LICENSE=$(gcloud secrets versions access latest --secret=norsk-license --project=${gcp_project})
STUDIO_PASSWORD=$(gcloud secrets versions access latest --secret=norsk-studio-password --project=${gcp_project})

# Fetch configuration from instance metadata
echo "Fetching configuration from instance metadata..."
DOMAIN_NAME=$(curl -sf -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/deploy_domain_name || echo "")

CERTBOT_EMAIL=$(curl -sf -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/deploy_certbot_email || echo "")

HARDWARE_OVERRIDE=$(curl -sf -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/hardware_profile || echo "auto")

REPO_BRANCH=$(curl -sf -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/repo_branch || echo "${repo_branch}")

# Install git
echo "Installing git..."
apt-get update
apt-get install -y git

# Clone repo
echo "Cloning repository..."
mkdir -p /var/norsk-studio
cd /var/norsk-studio

if [ -d "norsk-studio-docker" ]; then
  echo "Repository already exists, pulling latest..."
  cd norsk-studio-docker
  git pull
else
  git clone -b "$REPO_BRANCH" https://github.com/norskvideo/norsk-studio-docker.git
  cd norsk-studio-docker
fi

# Run bootstrap
echo "Running bootstrap script..."
./scripts/bootstrap.sh \
  --platform=google \
  --hardware="$HARDWARE_OVERRIDE" \
  --license="$NORSK_LICENSE" \
  --password="$STUDIO_PASSWORD" \
  --domain="$DOMAIN_NAME" \
  --certbot-email="$CERTBOT_EMAIL"

# Reboot if GPU hardware detected (check installed config)
if grep -q 'DEPLOY_HARDWARE="nvidia"' deployed/*/norsk-config.sh 2>/dev/null; then
  echo "NVIDIA hardware detected, rebooting..."
  reboot
fi

echo "Startup script completed successfully"
