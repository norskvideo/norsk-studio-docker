#!/bin/bash

# Stack Script for installing Norsk Studio
# Tested with Ubuntu 22.04 LTS and Debian 12

# <UDF name="norsk_license" label="Norsk license JSON string" default="" />
# <UDF name="studio_password" label="Frontend password for norsk-studio-admin" default="" />
# <UDF name="hardware" label="Hardware profile (auto|none|quadra)" default="auto" />
# <UDF name="domain_name" label="(Optional) Public domain name for deployment" default="" />
# <UDF name="certbot_email" label="(Optional) Email for certbot renewal notices" default="" />

set -euxo pipefail

# Capture output of stackscript
echo "Logging to /root/stackscript.log"
exec >/root/stackscript.log 2>&1

# Install git and clone repo
apt-get update
apt-get install -y git

mkdir -p /var/norsk-studio
cd /var/norsk-studio
git clone -b git-mgt https://github.com/norskvideo/norsk-studio-docker.git

cd /var/norsk-studio/norsk-studio-docker

# Run bootstrap script (media download happens in 00-common.sh)
./scripts/bootstrap.sh \
  --hardware="$HARDWARE" \
  --platform=linode \
  --license="$NORSK_LICENSE" \
  --password="$STUDIO_PASSWORD" \
  --domain="$DOMAIN_NAME" \
  --certbot-email="$CERTBOT_EMAIL"

# Reboot if Quadra was detected/used (check for quadra in installed config)
if grep -q 'DEPLOY_HARDWARE="quadra"' deployed/*/norsk-config.sh 2>/dev/null; then
  reboot
fi
